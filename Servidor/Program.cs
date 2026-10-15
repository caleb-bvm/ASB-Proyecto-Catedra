using System.Data;
using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.FileProviders;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 32 * 1024);
builder.WebHost.UseUrls("http://127.0.0.1:" + (Environment.GetEnvironmentVariable("FONAVIT_PORT") ?? "8765"));
var connectionString = Environment.GetEnvironmentVariable("FONAVIT_CONNECTION_STRING")
    ?? "Server=.\\SQLEXPRESS;Database=FonaVitSV_Fase2;Integrated Security=true;Encrypt=true;TrustServerCertificate=true;Connect Timeout=5";
var db = new Database(connectionString);
var app = builder.Build();
app.Use(async (context, next) =>
{
    // Solo acceso local. Rechaza sitios externos que intenten escribir en la API.
    if (context.Request.Host.Host is not ("127.0.0.1" or "localhost"))
    {
        context.Response.StatusCode = 403;
        return;
    }
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    if (context.Request.Path.StartsWithSegments("/api"))
    {
        context.Response.Headers.CacheControl = "no-store";
        var origin = context.Request.Headers.Origin.ToString();
        if (origin.Length > 0 && origin != $"{context.Request.Scheme}://{context.Request.Host}")
        {
            context.Response.StatusCode = 403;
            await context.Response.WriteAsJsonAsync(new { error = "Origen no permitido." });
            return;
        }
    }
    try { await next(context); }
    catch (ValidationException e)
    {
        context.Response.StatusCode = 400;
        await context.Response.WriteAsJsonAsync(new { error = e.Message });
    }
    catch (SqlException e)
    {
        app.Logger.LogError(e, "Error al operar con SQL Server");
        context.Response.StatusCode = e.Number is 2601 or 2627 or 547 or 1205 ? 409 : 503;
        var message = e.Number switch
        {
            2601 or 2627 => "Este documento o número de cuenta ya está registrado.",
            547 => "SQL Server rechazó el registro. Revisa las relaciones y los valores ingresados.",
            1205 => "Otra operación modificó estos registros. Actualiza los datos e intenta de nuevo.",
            _ => "No se pudo conectar con SQL Server. Comprueba la instancia y la base de datos."
        };
        await context.Response.WriteAsJsonAsync(new { error = message });
    }
    catch (BadHttpRequestException)
    {
        context.Response.StatusCode = 400;
        await context.Response.WriteAsJsonAsync(new { error = "Solicitud JSON inválida." });
    }
});
app.MapGet("/api/data", () => db.Run(null));
app.MapPost("/api/records", (Operation operation) => db.Run(operation));
app.MapGet("/api/health", async () =>
{
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    return Results.Ok(new { connected = true, database = connection.Database, server = connection.DataSource });
});
app.Map("/api/{**path}", () => Results.NotFound(new { error = "Ruta de API no disponible." }));
var prototype = Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "../Prototipo"));
if (!Directory.Exists(prototype)) prototype = Path.Combine(AppContext.BaseDirectory, "wwwroot");
var files = new PhysicalFileProvider(prototype);
app.UseDefaultFiles(new DefaultFilesOptions { FileProvider = files });
app.UseStaticFiles(new StaticFileOptions { FileProvider = files, OnPrepareResponse = c => c.Context.Response.Headers.CacheControl = "no-cache" });
app.Run();

record Operation(string Kind, int Id, Dictionary<string, string> Values);
sealed class ValidationException(string message) : Exception(message);

sealed class Database(string connectionString)
{
    private static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById("Central America Standard Time");
    private static DateOnly Today => DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, Zone));
    public async Task<JsonElement> Run(Operation? operation)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable);
        // Ordena operaciones del prototipo y evita carreras en cuentas y jefaturas.
        var lockResult = Convert.ToInt32(await Scalar(connection, transaction, "DECLARE @result int; EXEC @result=sys.sp_getapplock @Resource=N'FonaVitSV_Prototipo', @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000; SELECT @result;"));
        if (lockResult < 0) throw new ValidationException("La base está ocupada. Intenta de nuevo.");
        if (operation != null) await Write(connection, transaction, operation);
        var state = await Read(connection, transaction);
        await transaction.CommitAsync();
        return state;
    }

    private static SqlCommand Command(SqlConnection c, SqlTransaction tx, string sql, params (string, object?)[] parameters)
    {
        var command = new SqlCommand(sql, c, tx);
        foreach (var (name, value) in parameters) command.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return command;
    }
    private static async Task<object?> Scalar(SqlConnection c, SqlTransaction tx, string sql, params (string, object?)[] parameters)
    {
        await using var command = Command(c, tx, sql, parameters);
        return await command.ExecuteScalarAsync();
    }
    private static async Task Execute(SqlConnection c, SqlTransaction tx, string sql, params (string, object?)[] parameters)
    {
        await using var command = Command(c, tx, sql, parameters);
        await command.ExecuteNonQueryAsync();
    }
    private static async Task<JsonElement> Read(SqlConnection c, SqlTransaction tx)
    {
        const string sql = """
        SELECT
          JSON_QUERY((SELECT codigo_cliente id,nombre_completo name,documento_identidad dui,
            CONVERT(char(10),fecha_nacimiento,23) birth,calle street,casa house,ciudad city,
            departamento department,estado_familiar family,beneficiario beneficiary
            FROM dbo.CLIENTE ORDER BY codigo_cliente FOR JSON PATH,INCLUDE_NULL_VALUES)) clients,
          JSON_QUERY((SELECT codigo_empleado id,nombre_completo name,documento_identidad dui,
            CONVERT(char(10),fecha_nacimiento,23) birth,calle street,casa house,ciudad city,
            departamento department,puesto role,sueldo salary,codigo_jefe boss
            FROM dbo.EMPLEADO ORDER BY codigo_empleado FOR JSON PATH,INCLUDE_NULL_VALUES)) employees,
          JSON_QUERY((SELECT numero_cuenta id,codigo_cliente client,CONVERT(char(10),fecha_apertura,23) date,estado status
            FROM dbo.CUENTA ORDER BY numero_cuenta FOR JSON PATH)) accounts,
          JSON_QUERY((SELECT codigo_transaccion id,numero_cuenta account,documento_persona dui,codigo_usuario employee,
            monto amount,CONVERT(varchar(19),fecha,126) date FROM dbo.TRANSACCION ORDER BY codigo_transaccion FOR JSON PATH)) transactions,
          JSON_QUERY((SELECT codigo_prestamo id,numero_cuenta account,codigo_usuario employee,valor_prestamo amount,
            CONVERT(char(10),fecha_desembolso,23) date,interes_anual rate,tiempo_meses months,estado status
            FROM dbo.PRESTAMO ORDER BY codigo_prestamo FOR JSON PATH)) loans,
          JSON_QUERY((SELECT codigo_auditoria id,tabla [table],codigo_registro record,operacion operation,
            CONVERT(varchar(19),fecha_utc,126)+'Z' date,usuario_sql [user],datos_anteriores [before],datos_nuevos [after]
            FROM dbo.AUDITORIA ORDER BY codigo_auditoria FOR JSON PATH,INCLUDE_NULL_VALUES)) audit,
          DB_NAME() [database],1 version
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER;
        """;
        await using var command = Command(c, tx, sql);
        await using var reader = await command.ExecuteReaderAsync();
        var json = new System.Text.StringBuilder();
        while (await reader.ReadAsync()) json.Append(reader.GetString(0));
        using var document = JsonDocument.Parse(json.ToString());
        return document.RootElement.Clone();
    }
    private static string Text(Dictionary<string, string> v, string key, int max)
    {
        var value = v.GetValueOrDefault(key)?.Trim() ?? "";
        if (value.Length == 0 || value.Length > max) throw new ValidationException($"Revisa el campo {key}: es obligatorio y admite hasta {max} caracteres.");
        return value;
    }
    private static string Dui(Dictionary<string, string> v)
    {
        var dui = Text(v, "dui", 10);
        if (!Regex.IsMatch(dui, @"\A[0-9]{8}-[0-9]\z")) throw new ValidationException("El DUI debe tener el formato 00000000-0.");
        return dui;
    }
    private static DateOnly Date(Dictionary<string, string> v, string key)
    {
        if (!DateOnly.TryParseExact(v.GetValueOrDefault(key), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
            throw new ValidationException("Ingresa una fecha válida.");
        if (date > Today) throw new ValidationException("La fecha no puede ser posterior a hoy.");
        return date;
    }
    private static decimal Number(Dictionary<string, string> v, string key, decimal min, decimal max, bool integer = false)
    {
        if (!decimal.TryParse(v.GetValueOrDefault(key), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var value)
            || value < min || value > max || decimal.Round(value, integer ? 0 : 2) != value)
            throw new ValidationException($"Revisa el campo {key}: rango {min} a {max}, {(integer ? "solo enteros" : "máximo dos decimales")}.");
        return value;
    }
    private static async Task Require(SqlConnection c, SqlTransaction tx, string sql, string message, params (string, object?)[] parameters)
    {
        if (Convert.ToInt32(await Scalar(c, tx, sql, parameters)) == 0) throw new ValidationException(message);
    }
    private static async Task AddAccount(SqlConnection c, SqlTransaction tx, int client)
    {
        await Require(c, tx, "SELECT COUNT(*) FROM dbo.CLIENTE WHERE codigo_cliente=@id", "El cliente ya no existe.", ("@id", client));
        var prefix = $"CTA-{Today.Year}-";
        var next = Convert.ToInt32(await Scalar(c, tx,
            "SELECT COALESCE(MAX(TRY_CONVERT(int,SUBSTRING(numero_cuenta,10,11))),0)+1 FROM dbo.CUENTA WITH(UPDLOCK,HOLDLOCK) WHERE numero_cuenta LIKE @prefix+'%'", ("@prefix", prefix)));
        await Execute(c, tx, "INSERT dbo.CUENTA(numero_cuenta,codigo_cliente,fecha_apertura,estado) VALUES(@account,@client,@date,'Activa')",
            ("@account", prefix + next.ToString("D4")), ("@client", client), ("@date", Today.ToDateTime(TimeOnly.MinValue)));
    }
    private static async Task Write(SqlConnection c, SqlTransaction tx, Operation op)
    {
        if (op.Values == null || op.Id < 0) throw new ValidationException("Solicitud inválida.");
        var v = op.Values;
        if (op.Kind is "client" or "employee")
        {
            var employee = op.Kind == "employee";
            // Solo nombres de tabla y columna fijos; los datos siempre son parámetros.
            var table = employee ? "EMPLEADO" : "CLIENTE";
            var idColumn = employee ? "codigo_empleado" : "codigo_cliente";
            if (op.Id > 0) await Require(c, tx, $"SELECT COUNT(*) FROM dbo.{table} WHERE {idColumn}=@id", "El registro ya no existe.", ("@id", op.Id));
            var birth = Date(v, "birth");
            if (birth < new DateOnly(1900, 1, 1)) throw new ValidationException("Revisa la fecha de nacimiento.");
            var parameters = new List<(string, object?)>
            {
                ("@name",Text(v,"name",120)), ("@dui",Dui(v)), ("@birth",birth.ToDateTime(TimeOnly.MinValue)),
                ("@street",Text(v,"street",120)), ("@house",Text(v,"house",20)),
                ("@city",Text(v,"city",80)), ("@department",Text(v,"department",80)), ("@id",op.Id)
            };
            string columns, values, updates;
            if (employee)
            {
                int? boss = null;
                var rawBoss = v.GetValueOrDefault("boss")?.Trim();
                if (!string.IsNullOrEmpty(rawBoss))
                {
                    if (!int.TryParse(rawBoss, out var bossId) || bossId <= 0) throw new ValidationException("Selecciona un jefe válido.");
                    boss = bossId;
                    var seen = new HashSet<int>();
                    if (op.Id > 0) seen.Add(op.Id);
                    int? current = boss;
                    while (current != null)
                    {
                        if (!seen.Add(current.Value)) throw new ValidationException("La jerarquía de jefes no puede formar un ciclo.");
                        var parent = await Scalar(c, tx, "SELECT codigo_jefe FROM dbo.EMPLEADO WITH(UPDLOCK,HOLDLOCK) WHERE codigo_empleado=@id", ("@id",current));
                        if (parent == null) throw new ValidationException("El jefe seleccionado no existe.");
                        current = parent is DBNull ? null : Convert.ToInt32(parent);
                    }
                }
                parameters.AddRange([("@role",Text(v,"role",60)),("@salary",Number(v,"salary",0.01m,9999999999.99m)),("@boss",boss)]);
                columns = "puesto,sueldo,codigo_jefe"; values = "@role,@salary,@boss";
                updates = "puesto=@role,sueldo=@salary,codigo_jefe=@boss";
            }
            else
            {
                var family = Text(v,"family",20);
                if (family is not ("Soltero/a" or "Casado/a" or "Acompañado/a" or "Divorciado/a" or "Viudo/a")) throw new ValidationException("Estado familiar inválido.");
                parameters.AddRange([("@family",family),("@beneficiary",Text(v,"beneficiary",120))]);
                columns = "estado_familiar,beneficiario"; values = "@family,@beneficiary";
                updates = "estado_familiar=@family,beneficiario=@beneficiary";
            }
            if (op.Id > 0)
                await Execute(c, tx, $"UPDATE dbo.{table} SET nombre_completo=@name,documento_identidad=@dui,fecha_nacimiento=@birth,calle=@street,casa=@house,ciudad=@city,departamento=@department,{updates} WHERE {idColumn}=@id", parameters.ToArray());
            else
            {
                // SCOPE_IDENTITY funciona aunque CLIENTE tenga un trigger de auditoría.
                var id = Convert.ToInt32(await Scalar(c, tx, $"INSERT dbo.{table}(nombre_completo,documento_identidad,fecha_nacimiento,calle,casa,ciudad,departamento,{columns}) VALUES(@name,@dui,@birth,@street,@house,@city,@department,{values}); SELECT CAST(SCOPE_IDENTITY() AS int);", parameters.ToArray()));
                if (!employee) await AddAccount(c, tx, id);
            }
        }
        else if (op.Kind == "account")
        {
            if (op.Id <= 0) throw new ValidationException("Selecciona un cliente válido.");
            await AddAccount(c, tx, op.Id);
        }
        else if (op.Kind is "transaction" or "loan")
        {
            var account = Text(v,"account",20);
            await using var cmd = Command(c, tx, "SELECT fecha_apertura,estado FROM dbo.CUENTA WITH(UPDLOCK,HOLDLOCK) WHERE numero_cuenta=@account", ("@account",account));
            DateOnly opened;
            await using (var reader = await cmd.ExecuteReaderAsync())
            {
                if (!await reader.ReadAsync() || reader.GetString(1) != "Activa") throw new ValidationException("Selecciona una cuenta activa.");
                opened = DateOnly.FromDateTime(reader.GetDateTime(0));
            }
            var date = Date(v,"date");
            if (date < opened) throw new ValidationException("La fecha debe estar entre la apertura de la cuenta y hoy.");
            var amount = Number(v,"amount",0.01m,9999999999.99m);
            var employee = (int)Number(v,"employee",1,int.MaxValue,true);
            await Require(c, tx, "SELECT COUNT(*) FROM dbo.EMPLEADO WHERE codigo_empleado=@id", "Selecciona un empleado válido.", ("@id",employee));
            if (op.Kind == "transaction")
            {
                var type = Text(v,"type",10);
                if (type is not ("deposit" or "withdraw")) throw new ValidationException("Tipo de movimiento inválido.");
                if (type == "withdraw")
                {
                    var balance = Convert.ToDecimal(await Scalar(c, tx, "SELECT COALESCE(SUM(monto),0) FROM dbo.TRANSACCION WITH(UPDLOCK,HOLDLOCK) WHERE numero_cuenta=@account", ("@account",account)));
                    if (amount > balance) throw new ValidationException("Saldo insuficiente. El retiro no fue registrado.");
                    amount = -amount;
                }
                await Execute(c, tx, "INSERT dbo.TRANSACCION(numero_cuenta,documento_persona,codigo_usuario,monto,fecha) VALUES(@account,@dui,@employee,@amount,@date)",
                    ("@account",account),("@dui",Dui(v)),("@employee",employee),("@amount",amount),("@date",date.ToDateTime(TimeOnly.MinValue)));
            }
            else
                await Execute(c, tx, "INSERT dbo.PRESTAMO(numero_cuenta,codigo_usuario,valor_prestamo,fecha_desembolso,interes_anual,tiempo_meses,estado) VALUES(@account,@employee,@amount,@date,@rate,@months,N'Al día')",
                    ("@account",account),("@employee",employee),("@amount",amount),("@date",date.ToDateTime(TimeOnly.MinValue)),
                    ("@rate",Number(v,"rate",0,100)),("@months",(int)Number(v,"months",1,360,true)));
        }
        else if (op.Kind == "status")
        {
            var status = Text(v,"status",12);
            if (status is not ("Al día" or "Atrasado" or "Pagado")) throw new ValidationException("Estado de préstamo inválido.");
            await Require(c, tx, "SELECT COUNT(*) FROM dbo.PRESTAMO WHERE codigo_prestamo=@id", "El préstamo ya no existe.", ("@id",op.Id));
            await Execute(c, tx, "UPDATE dbo.PRESTAMO SET estado=@status WHERE codigo_prestamo=@id", ("@status",status),("@id",op.Id));
        }
        else throw new ValidationException("Operación no disponible.");
    }
}

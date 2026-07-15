var builder = WebApplication.CreateBuilder();

var app = builder.Build();

app.UseDefaultFiles();
app.UseStaticFiles();

app.Run();
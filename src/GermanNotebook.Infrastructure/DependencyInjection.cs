using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace GermanNotebook.Infrastructure
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddInfrastructure(
            this IServiceCollection services, IConfiguration config)
        {
            var connectionString = config.GetConnectionString("Default")
                ?? throw new InvalidOperationException(
                    "ConnectionSTrings:Default is not configured");

            services.AddNpgsqlDataSource(connectionString);
            return services;
        }
    }
}

"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const cache_manager_1 = require("@nestjs/cache-manager");
const core_1 = require("@nestjs/core");
const http_exception_filter_1 = require("./compartido/filtros/http-exception.filter");
const rate_limit_guard_1 = require("./compartido/guards/rate-limit.guard");
const respuesta_interceptor_1 = require("./compartido/interceptores/respuesta.interceptor");
const auth_module_1 = require("./core/auth/auth.module");
const cache_menu_module_1 = require("./core/cache/cache-menu.module");
const configuracion_global_module_1 = require("./core/config/configuracion-global.module");
const database_module_1 = require("./core/database/database.module");
const realtime_module_1 = require("./core/realtime/realtime.module");
const ciudades_module_1 = require("./modulos/ciudades/ciudades.module");
const dashboard_module_1 = require("./modulos/dashboard/dashboard.module");
const menu_module_1 = require("./modulos/menu/menu.module");
const dispositivos_module_1 = require("./modulos/dispositivos/dispositivos.module");
const mesas_module_1 = require("./modulos/mesas/mesas.module");
const pedidos_module_1 = require("./modulos/pedidos/pedidos.module");
const restaurantes_module_1 = require("./modulos/restaurantes/restaurantes.module");
const salud_module_1 = require("./modulos/salud/salud.module");
const super_admin_module_1 = require("./modulos/super-admin/super-admin.module");
const caja_module_1 = require("./modulos/caja/caja.module");
const catalogo_module_1 = require("./modulos/catalogo/catalogo.module");
const cocinas_module_1 = require("./modulos/cocinas/cocinas.module");
const inventario_module_1 = require("./modulos/inventario/inventario.module");
const domiciliarios_module_1 = require("./modulos/domiciliarios/domiciliarios.module");
const reportes_module_1 = require("./modulos/reportes/reportes.module");
const analitica_module_1 = require("./modulos/analitica/analitica.module");
const finanzas_module_1 = require("./modulos/finanzas/finanzas.module");
const alertas_module_1 = require("./modulos/alertas/alertas.module");
const usuarios_module_1 = require("./modulos/usuarios/usuarios.module");
const facturacion_module_1 = require("./modulos/facturacion/facturacion.module");
const zonas_module_1 = require("./modulos/zonas/zonas.module");
const promociones_module_1 = require("./modulos/promociones/promociones.module");
const costeo_module_1 = require("./modulos/costeo/costeo.module");
const geografia_module_1 = require("./modulos/geografia/geografia.module");
const notificaciones_module_1 = require("./modulos/notificaciones/notificaciones.module");
const auditoria_module_1 = require("./modulos/auditoria/auditoria.module");
const caja_movimientos_module_1 = require("./core/caja/caja-movimientos.module");
const suscripciones_cron_module_1 = require("./core/suscripciones/suscripciones-cron.module");
const pagos_module_1 = require("./modulos/pagos/pagos.module");
const almacenamiento_module_1 = require("./modulos/almacenamiento/almacenamiento.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({ isGlobal: true }),
            cache_manager_1.CacheModule.register({
                isGlobal: true,
                ttl: 900_000,
                max: 200,
            }),
            cache_menu_module_1.CacheMenuModule,
            database_module_1.DatabaseModule,
            configuracion_global_module_1.ConfiguracionGlobalModule,
            caja_movimientos_module_1.CajaMovimientosModule,
            realtime_module_1.RealtimeModule,
            auth_module_1.AuthModule,
            salud_module_1.SaludModule,
            ciudades_module_1.CiudadesModule,
            restaurantes_module_1.RestaurantesModule,
            menu_module_1.MenuModule,
            dashboard_module_1.DashboardModule,
            pedidos_module_1.PedidosModule,
            dispositivos_module_1.DispositivosModule,
            mesas_module_1.MesasModule,
            super_admin_module_1.SuperAdminModule,
            caja_module_1.CajaModule,
            catalogo_module_1.CatalogoModule,
            cocinas_module_1.CocinasModule,
            inventario_module_1.InventarioModule,
            domiciliarios_module_1.DomiciliariosModule,
            reportes_module_1.ReportesModule,
            analitica_module_1.AnaliticaModule,
            finanzas_module_1.FinanzasModule,
            alertas_module_1.AlertasModule,
            usuarios_module_1.UsuariosModule,
            facturacion_module_1.FacturacionModule,
            zonas_module_1.ZonasModule,
            promociones_module_1.PromocionesModule,
            costeo_module_1.CosteoModule,
            geografia_module_1.GeografiaModule,
            notificaciones_module_1.NotificacionesModule,
            auditoria_module_1.AuditoriaModule,
            suscripciones_cron_module_1.SuscripcionesCronModule,
            pagos_module_1.PagosModule,
            almacenamiento_module_1.AlmacenamientoModule,
        ],
        providers: [
            {
                provide: core_1.APP_INTERCEPTOR,
                useClass: respuesta_interceptor_1.RespuestaInterceptor,
            },
            {
                provide: core_1.APP_FILTER,
                useClass: http_exception_filter_1.HttpExceptionFilter,
            },
            {
                provide: core_1.APP_GUARD,
                useClass: rate_limit_guard_1.RateLimitGuard,
            },
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map
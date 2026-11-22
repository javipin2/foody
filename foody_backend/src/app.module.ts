import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CacheModule } from '@nestjs/cache-manager';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { HttpExceptionFilter } from './compartido/filtros/http-exception.filter';
import { RateLimitGuard } from './compartido/guards/rate-limit.guard';
import { RespuestaInterceptor } from './compartido/interceptores/respuesta.interceptor';
import { AuthModule } from './core/auth/auth.module';
import { CacheMenuModule } from './core/cache/cache-menu.module';
import { ConfiguracionGlobalModule } from './core/config/configuracion-global.module';
import { DatabaseModule } from './core/database/database.module';
import { RealtimeModule } from './core/realtime/realtime.module';
import { CiudadesModule } from './modulos/ciudades/ciudades.module';
import { DashboardModule } from './modulos/dashboard/dashboard.module';
import { MenuModule } from './modulos/menu/menu.module';
import { DispositivosModule } from './modulos/dispositivos/dispositivos.module';
import { MesasModule } from './modulos/mesas/mesas.module';
import { PedidosModule } from './modulos/pedidos/pedidos.module';
import { RestaurantesModule } from './modulos/restaurantes/restaurantes.module';
import { SaludModule } from './modulos/salud/salud.module';
import { SuperAdminModule } from './modulos/super-admin/super-admin.module';
import { CajaModule } from './modulos/caja/caja.module';
import { CatalogoModule } from './modulos/catalogo/catalogo.module';
import { CocinasModule } from './modulos/cocinas/cocinas.module';
import { InventarioModule } from './modulos/inventario/inventario.module';
import { DomiciliariosModule } from './modulos/domiciliarios/domiciliarios.module';
import { ReportesModule } from './modulos/reportes/reportes.module';
import { AnaliticaModule } from './modulos/analitica/analitica.module';
import { FinanzasModule } from './modulos/finanzas/finanzas.module';
import { AlertasModule } from './modulos/alertas/alertas.module';
import { UsuariosModule } from './modulos/usuarios/usuarios.module';
import { FacturacionModule } from './modulos/facturacion/facturacion.module';
import { ZonasModule } from './modulos/zonas/zonas.module';
import { PromocionesModule } from './modulos/promociones/promociones.module';
import { CosteoModule } from './modulos/costeo/costeo.module';
import { GeografiaModule } from './modulos/geografia/geografia.module';
import { NotificacionesModule } from './modulos/notificaciones/notificaciones.module';
import { AuditoriaModule } from './modulos/auditoria/auditoria.module';
import { CajaMovimientosModule } from './core/caja/caja-movimientos.module';
import { SuscripcionesCronModule } from './core/suscripciones/suscripciones-cron.module';
import { PagosModule } from './modulos/pagos/pagos.module';
import { AlmacenamientoModule } from './modulos/almacenamiento/almacenamiento.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    CacheModule.register({
      isGlobal: true,
      ttl: 900_000,
      max: 200,
    }),
    CacheMenuModule,
    DatabaseModule,
    ConfiguracionGlobalModule,
    CajaMovimientosModule,
    RealtimeModule,
    AuthModule,
    SaludModule,
    CiudadesModule,
    RestaurantesModule,
    MenuModule,
    DashboardModule,
    PedidosModule,
    DispositivosModule,
    MesasModule,
    SuperAdminModule,
    CajaModule,
    CatalogoModule,
    CocinasModule,
    InventarioModule,
    DomiciliariosModule,
    ReportesModule,
    AnaliticaModule,
    FinanzasModule,
    AlertasModule,
    UsuariosModule,
    FacturacionModule,
    ZonasModule,
    PromocionesModule,
    CosteoModule,
    GeografiaModule,
    NotificacionesModule,
    AuditoriaModule,
    SuscripcionesCronModule,
    PagosModule,
    AlmacenamientoModule,
  ],
  providers: [
    {
      provide: APP_INTERCEPTOR,
      useClass: RespuestaInterceptor,
    },
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
    {
      provide: APP_GUARD,
      useClass: RateLimitGuard,
    },
  ],
})
export class AppModule {}

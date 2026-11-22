"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PedidosModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../../core/auth/auth.module");
const alertas_module_1 = require("../alertas/alertas.module");
const auditoria_module_1 = require("../auditoria/auditoria.module");
const costeo_module_1 = require("../costeo/costeo.module");
const catalogo_module_1 = require("../catalogo/catalogo.module");
const facturacion_module_1 = require("../facturacion/facturacion.module");
const zonas_module_1 = require("../zonas/zonas.module");
const promociones_module_1 = require("../promociones/promociones.module");
const realtime_module_1 = require("../../core/realtime/realtime.module");
const impresion_module_1 = require("../../core/impresion/impresion.module");
const inventario_module_1 = require("../inventario/inventario.module");
const pedidos_controller_1 = require("./pedidos.controller");
const pedidos_public_controller_1 = require("./pedidos-public.controller");
const pedidos_service_1 = require("./pedidos.service");
const pedidos_caja_auditoria_service_1 = require("./pedidos-caja-auditoria.service");
const pedidos_cuenta_mesa_service_1 = require("./pedidos-cuenta-mesa.service");
const pedidos_crear_service_1 = require("./pedidos-crear.service");
const pedidos_estado_service_1 = require("./pedidos-estado.service");
const pedidos_pagos_service_1 = require("./pedidos-pagos.service");
const pedidos_soporte_service_1 = require("./pedidos-soporte.service");
const pedidos_items_service_1 = require("./pedidos-items.service");
const pedidos_descuento_service_1 = require("./pedidos-descuento.service");
const pedidos_estado_command_service_1 = require("./pedidos-estado-command.service");
const pedidos_inventario_service_1 = require("./pedidos-inventario.service");
const pedidos_dispatch_hooks_service_1 = require("./pedidos-dispatch-hooks.service");
const notificaciones_module_1 = require("../notificaciones/notificaciones.module");
const pedidos_qr_cron_service_1 = require("./pedidos-qr-cron.service");
let PedidosModule = class PedidosModule {
};
exports.PedidosModule = PedidosModule;
exports.PedidosModule = PedidosModule = __decorate([
    (0, common_1.Module)({
        imports: [
            auth_module_1.AuthModule,
            alertas_module_1.AlertasModule,
            auditoria_module_1.AuditoriaModule,
            costeo_module_1.CosteoModule,
            catalogo_module_1.CatalogoModule,
            facturacion_module_1.FacturacionModule,
            inventario_module_1.InventarioModule,
            zonas_module_1.ZonasModule,
            promociones_module_1.PromocionesModule,
            realtime_module_1.RealtimeModule,
            impresion_module_1.ImpresionModule,
            notificaciones_module_1.NotificacionesModule,
        ],
        controllers: [pedidos_controller_1.PedidosController, pedidos_public_controller_1.PedidosPublicController],
        providers: [
            pedidos_service_1.PedidosService,
            pedidos_caja_auditoria_service_1.PedidosCajaAuditoriaService,
            pedidos_cuenta_mesa_service_1.PedidosCuentaMesaService,
            pedidos_soporte_service_1.PedidosSoporteService,
            pedidos_estado_service_1.PedidosEstadoService,
            pedidos_crear_service_1.PedidosCrearService,
            pedidos_items_service_1.PedidosItemsService,
            pedidos_descuento_service_1.PedidosDescuentoService,
            pedidos_pagos_service_1.PedidosPagosService,
            pedidos_estado_command_service_1.PedidosEstadoCommandService,
            pedidos_inventario_service_1.PedidosInventarioService,
            pedidos_dispatch_hooks_service_1.PedidosDispatchHooksService,
            pedidos_qr_cron_service_1.PedidosQrCronService,
        ],
        exports: [
            pedidos_service_1.PedidosService,
            pedidos_caja_auditoria_service_1.PedidosCajaAuditoriaService,
            pedidos_cuenta_mesa_service_1.PedidosCuentaMesaService,
            pedidos_estado_service_1.PedidosEstadoService,
            pedidos_estado_command_service_1.PedidosEstadoCommandService,
            pedidos_inventario_service_1.PedidosInventarioService,
            pedidos_soporte_service_1.PedidosSoporteService,
            pedidos_dispatch_hooks_service_1.PedidosDispatchHooksService,
        ],
    })
], PedidosModule);
//# sourceMappingURL=pedidos.module.js.map
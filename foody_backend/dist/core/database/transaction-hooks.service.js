"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var TransactionHooksService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.TransactionHooksService = void 0;
const common_1 = require("@nestjs/common");
let TransactionHooksService = TransactionHooksService_1 = class TransactionHooksService {
    log = new common_1.Logger(TransactionHooksService_1.name);
    pendientes = new WeakMap();
    programarDespuesCommit(client, hook) {
        const lista = this.pendientes.get(client) ?? [];
        lista.push(hook);
        this.pendientes.set(client, lista);
    }
    ejecutarTrasCommit(client) {
        const lista = this.pendientes.get(client);
        this.pendientes.delete(client);
        if (!lista?.length)
            return;
        for (const hook of lista) {
            try {
                hook();
            }
            catch (e) {
                this.log.warn(`Hook post-commit falló: ${e instanceof Error ? e.message : e}`);
            }
        }
    }
    descartar(client) {
        this.pendientes.delete(client);
    }
};
exports.TransactionHooksService = TransactionHooksService;
exports.TransactionHooksService = TransactionHooksService = TransactionHooksService_1 = __decorate([
    (0, common_1.Injectable)()
], TransactionHooksService);
//# sourceMappingURL=transaction-hooks.service.js.map
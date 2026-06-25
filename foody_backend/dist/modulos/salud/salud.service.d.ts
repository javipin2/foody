import { DatabaseService } from '../../core/database/database.service';
export declare class SaludService {
    private readonly database;
    constructor(database: DatabaseService);
    verificar(): Promise<{
        api: string;
        version: string;
        base_datos: boolean;
        entorno: string;
        modulos: {
            mesas: string[];
            menu_mesa_qr: string;
            cocinas: string[];
            impresoras: string[];
            kds: string[];
            zonas: string[];
            geografia: string[];
            pedidos_dinero: string[];
            super_admin: string[];
            sucursales_staff: string[];
        };
    }>;
}

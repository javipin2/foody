import { MenuService } from './menu.service';
export declare class MenuController {
    private readonly menuService;
    constructor(menuService: MenuService);
    obtenerPorMesaQr(qrToken: string): Promise<{
        sucursal: {
            id: string;
            nombre: string;
            horario_activo: boolean;
            restaurante: {
                id: string;
                nombre: string;
            };
            ciudad: {
                id: string;
                nombre: string;
                slug: string;
            };
        };
        categorias: {
            id: string;
            nombre: string;
            orden: number;
            productos: {
                id: string;
                nombre: string;
                descripcion: string | null;
                precio: number;
                precio_para_llevar: number | null;
                imagen_url: string | null;
                disponible: boolean;
                es_encargo: boolean;
                toppings_disponibles: {
                    id: string;
                    nombre: string;
                    precio: number;
                }[];
                bebidas_disponibles: {
                    id: string;
                    nombre: string;
                    precio: number;
                }[];
            }[];
        }[];
        combos: {
            id: string;
            nombre: string;
            descripcion: string | null;
            precio_fijo: number;
            imagen_url: string | null;
            disponible: boolean;
            items: import("./menu.service").ComboItemFila[];
        }[];
        mesa: {
            id: string;
            nombre: string;
            qr_token: string;
            pedidos_activos: number;
            pedidos_pendientes_qr: number;
            total_pendiente_mesa: number;
        };
    }>;
    obtenerMenu(sucursalId: string): Promise<{
        sucursal: {
            id: string;
            nombre: string;
            horario_activo: boolean;
            restaurante: {
                id: string;
                nombre: string;
            };
            ciudad: {
                id: string;
                nombre: string;
                slug: string;
            };
        };
        categorias: {
            id: string;
            nombre: string;
            orden: number;
            productos: {
                id: string;
                nombre: string;
                descripcion: string | null;
                precio: number;
                precio_para_llevar: number | null;
                imagen_url: string | null;
                disponible: boolean;
                es_encargo: boolean;
                toppings_disponibles: {
                    id: string;
                    nombre: string;
                    precio: number;
                }[];
                bebidas_disponibles: {
                    id: string;
                    nombre: string;
                    precio: number;
                }[];
            }[];
        }[];
        combos: {
            id: string;
            nombre: string;
            descripcion: string | null;
            precio_fijo: number;
            imagen_url: string | null;
            disponible: boolean;
            items: import("./menu.service").ComboItemFila[];
        }[];
    }>;
}

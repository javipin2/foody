export type ProductoComboTopping = {
    id: string;
    nombre: string;
    cocina_id: string | null;
};
export type SeleccionToppingCombo = {
    topping_id: string;
    producto_id?: string;
};
export type DestinoToppingCombo = {
    topping_id: string;
    producto_id: string;
    producto_nombre: string;
    cocina_id: string | null;
};
export declare function resolverDestinosToppingsCombo(selecciones: SeleccionToppingCombo[], productos: ProductoComboTopping[]): DestinoToppingCombo[];
export declare function validarToppingsAsociadosAProductos(destinos: DestinoToppingCombo[], asociaciones: {
    producto_id: string;
    topping_id: string;
}[]): void;

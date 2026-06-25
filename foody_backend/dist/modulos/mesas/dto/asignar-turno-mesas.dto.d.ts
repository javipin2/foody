export declare class AsignacionMesaTurnoDto {
    mesa_id: string;
    mesera_asignada_id?: string | null;
}
export declare class AsignarTurnoMesasDto {
    sucursal_id: string;
    asignaciones: AsignacionMesaTurnoDto[];
}

import { RestaurantesService } from './restaurantes.service';
export declare class RestaurantesController {
    private readonly restaurantesService;
    constructor(restaurantesService: RestaurantesService);
    listarSucursales(id: string): Promise<import("pg").QueryResultRow[]>;
}

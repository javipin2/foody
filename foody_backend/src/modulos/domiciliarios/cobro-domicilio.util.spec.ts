import {
  montoVentaCajaEntregaDomicilio,
  repartirCobroDomicilio,
} from './cobro-domicilio.util';

describe('repartirCobroDomicilio', () => {
  it('separa saldo completo de producto y domicilio', () => {
    expect(repartirCobroDomicilio(110, 20, 0)).toEqual({
      saldo: 110,
      productoTotal: 90,
      productoPendiente: 90,
      domicilioPendiente: 20,
    });
  });

  it('imputa abonos previos primero al producto', () => {
    expect(repartirCobroDomicilio(110, 20, 40)).toEqual({
      saldo: 70,
      productoTotal: 90,
      productoPendiente: 50,
      domicilioPendiente: 20,
    });
  });

  it('detecta saldo de solo domicilio cuando el producto ya se abonó', () => {
    expect(repartirCobroDomicilio(110, 20, 90)).toEqual({
      saldo: 20,
      productoTotal: 90,
      productoPendiente: 0,
      domicilioPendiente: 20,
    });
  });

  it('no genera saldo negativo en pedidos pagados o sobrepagados', () => {
    expect(repartirCobroDomicilio(110, 20, 120)).toEqual({
      saldo: 0,
      productoTotal: 90,
      productoPendiente: 0,
      domicilioPendiente: 0,
    });
  });
});

describe('montoVentaCajaEntregaDomicilio', () => {
  it('solo lleva el saldo de productos a caja si el domicilio no es ingreso del local', () => {
    expect(montoVentaCajaEntregaDomicilio(110, 20, 40, false)).toBe(50);
    expect(montoVentaCajaEntregaDomicilio(110, 20, 40, true)).toBe(70);
  });
});

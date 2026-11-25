import { fechaHoyNegocio } from './fecha-negocio.util';

describe('fechaHoyNegocio', () => {
  it('usa la fecha de Bogotá cuando UTC ya cambió de día', () => {
    expect(fechaHoyNegocio(new Date('2026-02-01T02:30:00.000Z'))).toBe(
      '2026-01-31',
    );
  });

  it('cambia al mes siguiente al llegar la medianoche de Bogotá', () => {
    expect(fechaHoyNegocio(new Date('2026-02-01T05:00:00.000Z'))).toBe(
      '2026-02-01',
    );
  });
});

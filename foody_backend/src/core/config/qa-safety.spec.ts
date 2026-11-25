import { esQaSinEfectosExternos } from './qa-safety';

describe('esQaSinEfectosExternos', () => {
  const anterior = process.env.FOODY_QA_SIN_EFECTOS;

  afterEach(() => {
    if (anterior === undefined) delete process.env.FOODY_QA_SIN_EFECTOS;
    else process.env.FOODY_QA_SIN_EFECTOS = anterior;
  });

  it('solo activa el aislamiento con el valor explícito 1', () => {
    process.env.FOODY_QA_SIN_EFECTOS = '1';
    expect(esQaSinEfectosExternos()).toBe(true);

    process.env.FOODY_QA_SIN_EFECTOS = 'true';
    expect(esQaSinEfectosExternos()).toBe(false);

    delete process.env.FOODY_QA_SIN_EFECTOS;
    expect(esQaSinEfectosExternos()).toBe(false);
  });
});

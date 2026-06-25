import pg from 'pg';

const url = process.env.DATABASE_URL;
const pool = new pg.Pool({ connectionString: url });
try {
  const r = await pool.query('SELECT slug FROM ciudades LIMIT 1');
  console.log('OK', r.rows);
} catch (e) {
  console.error('ERROR', e.message);
  process.exit(1);
} finally {
  await pool.end();
}

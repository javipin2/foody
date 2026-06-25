const r = await fetch('http://127.0.0.1:3000/api/v1/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'admin@foody.demo', contrasena: '123456' }),
});
console.log(await r.text());

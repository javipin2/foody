/// PostgreSQL `numeric` suele llegar como String en JSON desde el API.
num parsearNumero(dynamic valor, {num porDefecto = 0}) {
  if (valor == null) return porDefecto;
  if (valor is num) return valor;
  if (valor is String) return num.tryParse(valor) ?? porDefecto;
  return porDefecto;
}

double parsearDouble(dynamic valor, {double porDefecto = 0}) {
  return parsearNumero(valor, porDefecto: porDefecto).toDouble();
}

# -*- coding: utf-8 -*-
"""Genera Word listo para Fondo Emprender CREAR 2026 (Foody + Tu Cancha Fácil)."""
from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

OUT = Path(__file__).resolve().parent / "FONDO_EMPRENDER_FOODY_TCF_LISTO.docx"

# --- Precios Año 1 (mejorados vs borrador anterior) ---
P1 = 50_000   # Foody Pro (plan mínimo de pago; hay Gratis de captura)
P2 = 100_000  # Foody Ultra (antes Premium / Pro superior)
P3 = 120_000  # Tu Cancha Fácil (plan base real)

# Unidades mes a mes Año 1 (suscripciones activas que pagan ese mes)
# TCF inicia en 1 = cliente real ya operando
Y1 = [
    # mes, p1, p2, p3
    (1, 5, 0, 1),
    (2, 10, 1, 1),
    (3, 18, 2, 2),
    (4, 28, 3, 2),
    (5, 40, 5, 3),
    (6, 55, 7, 4),
    (7, 72, 9, 5),
    (8, 90, 12, 6),
    (9, 110, 15, 7),
    (10, 130, 18, 8),
    (11, 155, 22, 9),
    (12, 180, 26, 10),
]

# Suscripción-meses Años 2-5 (promedio activos × 12) — conservador/creíble
Y25 = {
    #     P1     P2    P3
    2: (2_200, 480, 180),
    3: (3_600, 840, 300),
    4: (5_000, 1_200, 420),
    5: (6_400, 1_560, 540),
}

INV = 73_538_010  # tope individual 42 SMMLV
DESC = 0.10
COSTO_VAR_PCT = 0.06
MO_A1 = 2_500_000 * 1.5376 * 12  # salario + prestaciones ≈
FIJO_A1 = 18_000_000
PERMISO_A1 = 2_000_000
GASTOS_ADMIN = {
    1: 22_000_000,
    2: 48_000_000,
    3: 82_000_000,
    4: 120_000_000,
    5: 155_000_000,
}


def ventas_y1() -> tuple[int, int, int, int]:
    u1 = sum(r[1] for r in Y1)
    u2 = sum(r[2] for r in Y1)
    u3 = sum(r[3] for r in Y1)
    v = u1 * P1 + u2 * P2 + u3 * P3
    return u1, u2, u3, v


def precio(anio: int, base: int) -> int:
    return int(round(base * ((1.10) ** (anio - 1))))


def ventas_anio(anio: int) -> int:
    if anio == 1:
        return ventas_y1()[3]
    u1, u2, u3 = Y25[anio]
    return u1 * precio(anio, P1) + u2 * precio(anio, P2) + u3 * precio(anio, P3)


def mo_anio(anio: int) -> float:
    return MO_A1 * ((1.10) ** (anio - 1))


def fijo_anio(anio: int) -> float:
    return FIJO_A1 * ((1.10) ** (anio - 1))


def estado_resultados() -> list[dict]:
    rows = []
    for a in range(1, 6):
        v = ventas_anio(a)
        mp = int(round(v * COSTO_VAR_PCT))
        mo = int(round(mo_anio(a)))
        fi = int(round(fijo_anio(a)))
        pe = PERMISO_A1 if a == 1 else 0
        ub = v - mp - mo - fi - pe
        ga = GASTOS_ADMIN[a]
        un = ub - ga
        rows.append(
            {
                "anio": a,
                "ventas": v,
                "mp": mp,
                "mo": mo,
                "fijo": fi,
                "permiso": pe,
                "ub": ub,
                "ga": ga,
                "un": un,
            }
        )
    return rows


def npv(flujos: list[float], r: float) -> float:
    return sum(f / ((1 + r) ** t) for t, f in enumerate(flujos))


def irr(flujos: list[float], guess: float = 0.2) -> float | None:
    # Newton-Raphson simple
    r = guess
    for _ in range(80):
        f = sum(cf / ((1 + r) ** t) for t, cf in enumerate(flujos))
        df = sum(-t * cf / ((1 + r) ** (t + 1)) for t, cf in enumerate(flujos) if t > 0)
        if abs(df) < 1e-12:
            break
        nr = r - f / df
        if abs(nr - r) < 1e-8:
            return nr
        r = nr
    return r if abs(sum(cf / ((1 + r) ** t) for t, cf in enumerate(flujos))) < 1 else None


def money(n: float) -> str:
    n = int(round(n))
    s = f"{abs(n):,}".replace(",", ".")
    return f"-${s}" if n < 0 else f"${s}"


def money_m(n: float) -> str:
    return f"{n / 1_000_000:.1f}"


def set_run_font(run, size=11, bold=False, color=None):
    run.font.name = "Calibri"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Calibri")
    run.font.size = Pt(size)
    run.bold = bold
    if color:
        run.font.color.rgb = color


def add_h(doc, text, level=1):
    p = doc.add_heading(text, level=level)
    for run in p.runs:
        run.font.color.rgb = RGBColor(0xFF, 0x6B, 0x35) if level == 1 else RGBColor(0x2E, 0xC4, 0xB6)
    return p


def add_p(doc, text, bold=False, size=11, space_after=6):
    p = doc.add_paragraph()
    run = p.add_run(text)
    set_run_font(run, size=size, bold=bold)
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.space_before = Pt(0)
    return p


def add_quote(doc, text):
    p = doc.add_paragraph()
    run = p.add_run(text)
    set_run_font(run, size=11)
    p.paragraph_format.left_indent = Cm(0.5)
    p.paragraph_format.space_after = Pt(8)
    return p


def add_table(doc, headers, rows):
    t = doc.add_table(rows=1 + len(rows), cols=len(headers))
    t.style = "Table Grid"
    for i, h in enumerate(headers):
        cell = t.rows[0].cells[i]
        cell.text = ""
        run = cell.paragraphs[0].add_run(h)
        set_run_font(run, size=9, bold=True)
    for r_i, row in enumerate(rows):
        for c_i, val in enumerate(row):
            cell = t.rows[r_i + 1].cells[c_i]
            cell.text = ""
            run = cell.paragraphs[0].add_run(str(val))
            set_run_font(run, size=9)
    doc.add_paragraph()
    return t


def build():
    u1, u2, u3, v1 = ventas_y1()
    er = estado_resultados()
    flujos = [-INV] + [r["un"] for r in er]
    vpn = npv(flujos, DESC)
    tir = irr(flujos)
    tir_pct = (tir * 100) if tir is not None else float("nan")

    doc = Document()
    section = doc.sections[0]
    section.top_margin = Cm(1.8)
    section.bottom_margin = Cm(1.8)
    section.left_margin = Cm(2)
    section.right_margin = Cm(2)

    # Portada
    t = doc.add_paragraph()
    t.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = t.add_run("FONDO EMPRENDER — CREAR 2026")
    set_run_font(r, size=16, bold=True, color=RGBColor(0xFF, 0x6B, 0x35))

    t2 = doc.add_paragraph()
    t2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r2 = t2.add_run("Proyecto listo para diligenciar (celdas grises)")
    set_run_font(r2, size=13, bold=True)

    add_p(
        doc,
        "Empresa de software SaaS · Productos: Foody (POS restaurantes) + Tu Cancha Fácil (reservas de canchas sintéticas)",
        size=11,
    )
    add_p(
        doc,
        "Modalidad: Individual · Empleos: 1 · Monto solicitado: $73.538.010 (42 SMMLV) · Tasa descuento: 10%",
        bold=True,
    )
    add_p(
        doc,
        "Instrucción SENA: copiar SOLO a celdas grises de CREAR_ESP_PROYECTO_2026. No alterar fórmulas ni estructura del Excel.",
        size=10,
    )
    add_p(
        doc,
        "Los textos entre 〔corchetes〕 son datos personales: reemplázalos antes de entregar.",
        size=10,
    )

    add_h(doc, "0. Veredicto y mejoras respecto al borrador anterior", 1)
    add_p(
        doc,
        f"Viabilidad (escenario mejorado y más creíble): VPN ≈ {money(vpn)} · TIR ≈ {tir_pct:.0f}% "
        f"(umbral 10%). VEREDICTO: VIABLE.",
        bold=True,
    )
    add_p(doc, "Mejoras aplicadas en este documento:")
    for b in [
        "Tu Cancha Fácil a precio real de mercado: $120.000/mes (antes estaba subvalorado en $50.000).",
        "Foody alineado a planes comerciales: Pro $50.000 y Ultra $100.000 (más plan Gratis de captura, sin fila de venta $0).",
        "Capacidad instalada realista: escala por etapas (VPS → más recursos), sin declarar «ilimitada» ni 5.000+ simultáneos.",
        "Proyección Año 1 más conservadora y defendible ante evaluadores (sin inflar a 245+ Foody en mes 12).",
        "TCF inicia con 1 suscripción en mes 1 = cliente real ya operando (prueba de tracción).",
        "Narrativa dual: dolor de restaurantes + dolor de complejos de canchas; competencia en ambas verticales.",
        "Avances del proyecto actualizados: Foody MVP avanzado + TCF en producción con ingreso recurrente.",
        "Misma solicitud al tope individual ($73.538.010) con 1 empleo — coherente si trabajas solo.",
    ]:
        doc.add_paragraph(b, style="List Bullet")

    add_h(doc, "HOJA 2 — Integrantes de la iniciativa", 1)
    add_table(
        doc,
        ["Campo", "Valor"],
        [
            ["Nombres y apellidos", "〔Tu nombre completo〕"],
            ["Tipo / N.º documento", "CC 〔número〕"],
            ["Fecha de nacimiento", "〔dd/mm/aaaa〕"],
            ["Género", "〔Masculino/Femenino〕"],
            ["Nivel educativo", "〔Técnico/Tecnólogo/Profesional〕"],
            ["Programa / formación SENA", "〔si aplica〕"],
            ["Municipio / Departamento", "〔tu ciudad〕"],
            ["Teléfono / correo", "〔datos〕"],
            ["Rol en la iniciativa", "Líder / Representante — Desarrollador de software"],
        ],
    )
    add_p(doc, "Con 1 integrante el sistema clasifica el proyecto como Individual.")

    add_h(doc, "HOJA 1 — Proyecto", 1)
    add_h(doc, "Información general", 2)
    add_table(
        doc,
        ["Campo", "Qué poner"],
        [
            ["Líder o representante", "〔Tu nombre〕 — CC 〔número〕"],
            [
                "Nombre de la iniciativa",
                "Foody Labs (o tu marca empresarial) — software SaaS: Foody + Tu Cancha Fácil",
            ],
            ["Categoría del sector", "Todos los sectores"],
            ["Sector", "Servicios / Tecnologías de la Información"],
            ["Actividad económica (CIIU)", "6201 — Desarrollo de sistemas informáticos (software)"],
            ["Tipo de proyecto", "Individual"],
            [
                "¿Cuenta con lugar de operaciones?",
                "Sí (oficina/vivienda propia; se acreditará uso de suelo)",
            ],
        ],
    )

    add_h(doc, "1. ¿Quién es el cliente de su iniciativa?", 2)
    add_p(doc, "CLIENTE (características):", bold=True)
    add_quote(
        doc,
        "Mi cliente principal es el dueño o administrador de un negocio de comida en Colombia "
        "(restaurantes pequeños y medianos, dark kitchens, food trucks, cafeterías y comidas rápidas) "
        "y, como segunda línea ya validada, el dueño de un complejo de canchas sintéticas que necesita "
        "gestionar reservas por hora. Vive en zonas urbanas (inicialmente 〔tu ciudad/departamento〕 y "
        "capitales). Tiene entre 25 y 55 años, estrato 2 a 4, negocio familiar o independiente. "
        "Opera desde el celular, desconfía de herramientas caras o difíciles, y puede pagar "
        "$50.000–$120.000/mes si le reduce pérdidas o le organiza la operación. En Colombia hay más de "
        "90.000 restaurantes formales y cientos de miles de negocios de comida; además, una red amplia "
        "de canchas sintéticas en ciudades intermedias y barrios que hoy reservan por WhatsApp o cuaderno.",
    )
    add_p(doc, "CONSUMIDOR (cualidades / gustos):", bold=True)
    add_quote(
        doc,
        "Es práctico, evita lo complicado y el gasto innecesario. Le duele no saber si gana, que le roben "
        "inventario, no cuadrar caja, o (en canchas) que dos clientes peleen por la misma hora. Usa "
        "WhatsApp, Instagram y TikTok. Prefiere apps en español, sin contratos largos, con prueba gratis "
        "cuando aplique. En Foody se suscribe cuando ve control de pedidos/costeo/caja. En Tu Cancha Fácil "
        "se suscribe cuando ve que el cliente final aparta solo, se bloquea la hora y el abono se confirma "
        "sin pasarela compleja. Valora precio justo, rapidez y que no tenga que llamar a soporte.",
    )

    add_h(doc, "2. Planteamiento del problema o necesidad", 2)
    add_quote(
        doc,
        "Los pequeños negocios de comida no controlan su operación ni su dinero: no costean bien, pierden "
        "por inventario, no cuadran caja, llevan pedidos en papel y dependen de Rappi u otras apps con "
        "comisiones del 20–30%. Los POS buenos son caros; los baratos están incompletos. En paralelo, los "
        "complejos de canchas sintéticas pierden dinero y generan conflicto cuando la reserva se hace por "
        "chat: no hay bloqueo claro de hora, precios por franja, historial ni control de fraude/cambios "
        "riesgosos. El mercado necesita herramientas económicas, en español y móviles: Foody para comida "
        "y Tu Cancha Fácil para reservas de canchas — ambas ya construidas por el mismo equipo técnico, "
        "con TCF operando con cliente real que paga suscripción mensual.",
    )

    add_h(doc, "3. La competencia (3 competidores)", 2)
    add_table(
        doc,
        [
            "Nombre",
            "Localización",
            "Producto",
            "Precio $/mes",
            "Ventajas del competidor",
            "Desventajas frente a nosotros",
        ],
        [
            [
                "Loyverse",
                "Global / CO",
                "POS punto de venta",
                "$0 (+ add-ons)",
                "Gratis, conocido, sencillo",
                "Sin costeo de recetas, KDS, domicilios propios ni foco restaurante LATAM completo",
            ],
            [
                "Fudo",
                "Argentina / LATAM",
                "POS + comandas",
                "~$150.000",
                "Robusto en mesas/cocina",
                "Más caro; menos accesible al micro-emprendedor; sin logística propia tipo inDriver",
            ],
            [
                "Reservas por WhatsApp / Excel (canchas)",
                "Local",
                "Agenda informal",
                "$0 aparente",
                "Familiar, sin curva de aprendizaje",
                "Dobles reservas, sin precio por hora, sin bloqueo de abono, sin auditoría ni análisis",
            ],
        ],
    )
    add_p(doc, "Ventajas competitivas:", bold=True)
    add_quote(
        doc,
        "Foody entrega todo-en-uno (pedidos, mesas QR, cocina/KDS, inventario, costeo por plato, caja, "
        "domiciliarios propios, analítica y multi-sucursal) a precio accesible, freemium y sin instalación. "
        "Tu Cancha Fácil ya está en producción: sedes/canchas, precio por hora, bloqueo al confirmar, "
        "WhatsApp con datos de abono, aceptación/rechazo admin, historial, alertas de riesgo y reservas "
        "grupales/descuentos — sin pasarela obligatoria (encaja con cómo pagan hoy los dueños de cancha). "
        "La empresa no depende de un solo vertical: dos líneas SaaS con el mismo stack y costo marginal bajo.",
    )

    add_h(doc, "4. Descripción del proyecto", 2)
    add_p(doc, "El proyecto consiste en:", bold=True)
    add_quote(
        doc,
        "Crear y consolidar una empresa de desarrollo de software SaaS que comercializa dos aplicaciones: "
        "(1) Foody, POS y gestión integral para negocios de comida, con plan gratuito y planes de pago; y "
        "(2) Tu Cancha Fácil, sistema de reservas de horas de canchas sintéticas ya operando con cliente "
        "pagador. Los ingresos son recurrentes (suscripción mensual), con costo marginal casi nulo, "
        "operados inicialmente por el fundador-desarrollador.",
    )
    add_p(doc, "Propuesta de valor:", bold=True)
    for line in [
        "Nuestro: software Foody + Tu Cancha Fácil.",
        "Ayuda: a dueños de restaurantes/cocinas y a dueños de complejos de canchas.",
        "Que: necesitan controlar operación, dinero y reservas sin herramientas caras.",
        "Mediante: apps en español, por suscripción, usables desde el celular, con autoservicio.",
    ]:
        doc.add_paragraph(line, style="List Bullet")

    add_h(doc, "5. Productos o servicios (máximo 3)", 2)
    add_table(
        doc,
        ["#", "Nombre", "Descripción", "Unidad", "Presentación"],
        [
            [
                "1",
                "Foody Pro",
                "Suscripción mensual plan de pago mínimo (tras Gratis): pedidos, caja, menú, costeo, inventario, cocina/KDS, reportes",
                "Suscripción/mes",
                "Plan en la app (Play/App Store)",
            ],
            [
                "2",
                "Foody Ultra",
                "Suscripción superior: multi-sucursal, analítica avanzada (BI), techos altos",
                "Suscripción/mes",
                "Plan en la app",
            ],
            [
                "3",
                "Tu Cancha Fácil",
                "Suscripción plan base: sedes/canchas, reservas, precios por hora, bloqueo+WhatsApp abono, admin completo. Más canchas → plan superior",
                "Suscripción/mes",
                "App / panel web del producto",
            ],
        ],
    )
    add_p(
        doc,
        f"Precios Año 1: Foody Pro {money(P1)} · Foody Ultra {money(P2)} · Tu Cancha Fácil {money(P3)}. "
        "Incremento anual de precios: 10%. Plan Gratis = muestra/canal (no es producto de venta en esta hoja).",
        bold=True,
    )

    add_h(doc, "6. Proceso técnico", 2)
    add_table(
        doc,
        ["Actividad", "Tiempo", "Equipo/herramienta", "Quién"],
        [
            [
                "Desarrollo y mantenimiento (backend, apps, BD)",
                "Continuo",
                "PC desarrollo, VPS, Git",
                "Desarrollador (fundador)",
            ],
            [
                "Publicación Play Store / App Store",
                "2–3 días/versión",
                "Cuentas de desarrollador",
                "Desarrollador",
            ],
            [
                "Alta de cliente y activación de plan",
                "Minutos (auto)",
                "App + servidor",
                "Cliente (autoservicio)",
            ],
            [
                "Cobro suscripción (Wompi/PSE/tarjeta) o renovación TCF",
                "Mensual",
                "Pasarela / transferencia",
                "Sistema + admin",
            ],
            [
                "Soporte mínimo + tutoriales",
                "Según demanda",
                "Chat/correo/FAQ",
                "Desarrollador / autoservicio",
            ],
        ],
    )
    add_p(
        doc,
        "Capacidad instalada: servicio digital 24/7. La infraestructura escala por etapas "
        "(VPS de producción → más recursos o servidores adicionales → caché y base de datos dedicada "
        "cuando el crecimiento lo exija). Un VPS bien dimensionado atiende de forma estable cientos de "
        "suscriptores de pago (meta alineada a la proyección Año 1–2); el crecimiento hacia más cuentas "
        "se cubre con el rubro de nube del proyecto y costos variables por suscripción, sin reinventar "
        "el producto. Meta inicial: cientos de suscripciones de pago activas + plan gratuito controlado "
        "(límites y cupos), con margen para crecer sin parar el servicio. Aplica a Foody y a Tu Cancha Fácil.",
    )
    add_p(
        doc,
        "Nota para evaluadores: no se declara capacidad «ilimitada» ni decenas de miles de usuarios "
        "simultáneos en el año 1. Las proyecciones de ventas de este documento ya son coherentes con "
        "un VPS serio (~USD 50–100/mes, cubierto en costos fijos).",
        size=10,
    )

    add_h(doc, "7. Trámites legales", 2)
    add_p(doc, "Tipo de registro formal: S.A.S. (1 solo socio).", bold=True)
    add_table(
        doc,
        ["Norma / permiso", "Descripción", "Costo $", "Días"],
        [
            [
                "Constitución S.A.S. (NO financiable)",
                "Cámara de Comercio — la asume el emprendedor",
                "〔~$400.000〕",
                "3",
            ],
            ["RUT (DIAN)", "Inscripción tributaria", "$0", "1"],
            ["Registro de marca (SIC)", "Proteger Foody / Tu Cancha Fácil", "~$1.000.000", "30–180"],
            ["Registro software (DNDA)", "Derecho de autor del código", "~$60.000", "15"],
            ["Habeas Data (Ley 1581)", "Política de tratamiento de datos", "~$500.000", "10"],
            ["TOTAL trámites (aprox.)", "", "~$1.560.000 + constitución", ""],
        ],
    )

    add_h(doc, "8. Canales", 2)
    add_table(
        doc,
        ["Acción", "Valor Año 1"],
        [
            ["Publicidad redes (Meta, TikTok, Google Ads)", "$16.000.000"],
            ["Landing / web de descarga", "$1.500.000"],
            ["Video y piezas (Foody + TCF)", "$2.500.000"],
            ["Demostraciones / eventos locales", "$2.000.000"],
            ["TOTAL comunicación", "$22.000.000"],
        ],
    )
    add_p(doc, "Promoción: plan gratis Foody · demo TCF · descuento primer mes (opcional).")
    add_p(doc, "Distribución: Play Store / App Store + activación digital. Indicador eventos de mercadeo: 2.")

    add_h(doc, "9. Proyección de ventas", 2)
    add_p(
        doc,
        f"Precios celdas grises Año 1: P1={P1} · P2={P2} · P3={P3}. Incremento Años 2–5: 0,10.",
        bold=True,
    )
    add_p(doc, "Unidades (suscripciones activas) mes a mes — AÑO 1:", bold=True)
    add_table(
        doc,
        ["Mes", "P1 Foody Pro", "P2 Foody Ultra", "P3 Tu Cancha Fácil"],
        [[str(m), str(a), str(b), str(c)] for m, a, b, c in Y1]
        + [["Total año", str(u1), str(u2), str(u3)]],
    )
    add_p(
        doc,
        f"Ingresos Año 1 ≈ {money(v1)} "
        f"(Pro {money(u1 * P1)} + Ultra {money(u2 * P2)} + TCF {money(u3 * P3)}).",
        bold=True,
    )
    add_p(doc, "Unidades Años 2–5 (suscripción-meses = promedio activos × 12):", bold=True)
    add_table(
        doc,
        ["Producto", "Año 2", "Año 3", "Año 4", "Año 5"],
        [
            ["P1 Foody Pro", "2.200", "3.600", "5.000", "6.400"],
            ["P2 Foody Ultra", "480", "840", "1.200", "1.560"],
            ["P3 Tu Cancha Fácil", "180", "300", "420", "540"],
        ],
    )
    add_p(
        doc,
        "Justificación: Foody escala con freemium + ads hacia un mercado de cientos de miles de negocios "
        "de comida. TCF crece más lento (nicho de canchas) pero parte de tracción real (1 cliente pagando "
        f"{money(P3)}/mes) y ticket más alto. Precios +10%/año absorben inflación y mejoras de producto.",
    )

    add_h(doc, "10. Costos y gastos", 2)
    add_p(doc, "Costos fijos mensuales (NO incluir nómina aquí):", bold=True)
    add_table(
        doc,
        ["Descripción", "Mensual", "Meses A1", "Total A1"],
        [
            ["VPS / servidores producción", "$600.000", "12", "$7.200.000"],
            ["BD / almacenamiento / backups", "$250.000", "12", "$3.000.000"],
            ["Dominios, correo, SSL, túnel/CDN", "$50.000", "12", "$600.000"],
            ["Licencias dev/diseño", "$300.000", "12", "$3.600.000"],
            ["Honorarios contables", "$300.000", "12", "$3.600.000"],
            ["TOTAL", "$1.500.000", "", "$18.000.000"],
        ],
    )
    add_p(doc, "Costos variables (materia prima) por suscripción/mes:", bold=True)
    add_table(
        doc,
        ["Producto", "Concepto", "Valor"],
        [
            ["P1 Pro", "Pasarela (~2,65%) + infra variable", "$3.000"],
            ["P2 Ultra", "Pasarela + infra variable", "$4.500"],
            ["P3 TCF", "Infra + medios de cobro/ops", "$4.000"],
        ],
    )
    add_p(doc, "% participación en ventas (orientativo Año 1): P1 ~70% · P2 ~19% · P3 ~11%.")
    add_p(doc, "Gastos de administración y ventas (por año):", bold=True)
    add_table(
        doc,
        ["Concepto", "A1", "A2", "A3", "A4", "A5"],
        [
            [
                "Publicidad + admin/ops",
                money(GASTOS_ADMIN[1]),
                money(GASTOS_ADMIN[2]),
                money(GASTOS_ADMIN[3]),
                money(GASTOS_ADMIN[4]),
                money(GASTOS_ADMIN[5]),
            ]
        ],
    )

    add_h(doc, "11. Equipo de trabajo (empleos a crear)", 2)
    add_table(
        doc,
        ["Rol", "Vinculación", "Funciones", "Asignación mes", "Meses A1"],
        [
            [
                "Desarrollador / Fundador",
                "Contrato laboral indefinido",
                "Desarrollo, infra, publicación tiendas, marketing digital, soporte mínimo Foody+TCF",
                "$2.500.000",
                "12",
            ]
        ],
    )
    add_p(
        doc,
        "Factor prestacional ~53,76% lo suma la hoja → costo real ≈ $3.844.000/mes. Empleos a crear = 1. "
        "Empleos indirectos: 〔~5〕 (freelance diseño, contador, ads, nube).",
    )

    add_h(doc, "12. Necesidades y requerimientos (= valor solicitado)", 2)
    add_p(doc, "1. Inversiones fijas", bold=True)
    add_table(
        doc,
        ["Rubro", "Descripción", "Total"],
        [
            [
                "Maquinaria, equipos y software",
                "2 PCs alto rendimiento + monitores + periféricos",
                "$14.000.000",
            ],
            [
                "Maquinaria, equipos y software",
                "Licencias/herramientas de desarrollo y diseño",
                "$6.000.000",
            ],
            [
                "Bienes muebles (≤15%)",
                "Escritorio, silla ergonómica, mobiliario",
                "$6.000.000",
            ],
            ["TOTAL INVERSIONES FIJAS", "", "$26.000.000"],
        ],
    )
    add_p(doc, "2. Gastos preoperativos", bold=True)
    add_table(
        doc,
        ["Rubro", "Descripción", "Total"],
        [
            [
                "Salarios u honorarios",
                "Salario desarrollador ~5 meses (mín. 4 exigidos)",
                "$18.500.000",
            ],
            ["Estrategia de comunicación", "Publicidad de lanzamiento Foody + TCF", "$16.000.000"],
            ["Insumos ciclo productivo", "Nube prepago, APIs, push/SMS", "$8.000.000"],
            [
                "Propiedad intelectual (≤20%)",
                "Marca + software",
                "$4.000.000",
            ],
            ["Permisos, licencias y registros", "RUT, datos personales, otros", "$1.038.010"],
            ["TOTAL PREOPERATIVOS", "", "$47.538.010"],
        ],
    )
    add_p(
        doc,
        "TOTAL SOLICITADO = $73.538.010 (tope individual 1 empleo). Constitución S.A.S. NO financiable.",
        bold=True,
    )

    add_h(doc, "13. Valor de la iniciativa (autocompleta — debe quedar en verde)", 2)
    add_table(
        doc,
        ["Campo", "Valor"],
        [
            ["Integrantes", "1"],
            ["Valor solicitado", "$73.538.010"],
            ["Empleos a generar", "1"],
            ["Resultado esperado", "Cumple recursos, integrantes y empleos"],
        ],
    )

    add_h(doc, "14. Avances del proyecto a este momento", 2)
    for line in [
        "Legal: 〔en trámite / por constituir la S.A.S.〕.",
        "Comercial: marcas Foody y Tu Cancha Fácil; freemium Foody; TCF con cliente real pagando ~$120.000/mes.",
        "Técnico Foody: app funcional MVP avanzado (pedidos, mesas/QR, caja, cocina/KDS, inventario, costeo, domiciliarios, analítica, multi-sucursal, suscripciones).",
        "Técnico TCF: producto en producción — sedes/canchas, horarios y precio por hora, reserva cliente (nombre+teléfono), bloqueo de hora, WhatsApp con cuenta de abono, aceptación/rechazo admin, historial, análisis y controles de riesgo/fraude, reservas grupales y descuentos.",
        "Ambiental: operación 100% digital; reduce papel en comandas/cuadres/agendas.",
        "Ventas: TCF ya genera ingreso recurrente; Foody en preparación de lanzamiento comercial / piloto.",
        "Redes / web: 〔enlaces〕 · dominio demo Foody: foodyy.store (túnel/infra propia).",
    ]:
        doc.add_paragraph(line, style="List Bullet")

    add_h(doc, "15. Plan operativo (ejecución ≤ mes 9)", 2)
    add_table(
        doc,
        ["Rubro", "M1", "M2", "M3", "M4", "M5", "M6", "M7-9"],
        [
            ["Equipos y software", "14.000.000", "6.000.000", "", "", "", "", ""],
            ["Muebles", "6.000.000", "", "", "", "", "", ""],
            ["Registros / PI", "1.038.010", "4.000.000", "", "", "", "", ""],
            ["Insumos nube/APIs", "2.000.000", "1.500.000", "1.500.000", "1.000.000", "1.000.000", "1.000.000", ""],
            ["Publicidad lanzamiento", "", "4.000.000", "4.000.000", "4.000.000", "4.000.000", "", ""],
            ["Salarios (5 meses)", "3.700.000", "3.700.000", "3.700.000", "3.700.000", "3.700.000", "", ""],
        ],
    )
    add_p(doc, "La suma de la distribución debe ser exactamente $73.538.010.")

    add_h(doc, "16. Impacto", 2)
    add_p(
        doc,
        "Económico: 1 empleo formal directo y ~5 indirectos; mejora productividad de restaurantes y "
        "ocupación/control de canchas; empresa tecnológica escalable a LATAM.",
    )
    add_p(
        doc,
        "Social: profesionaliza micro-negocios de comida y complejos deportivos barriales; protege empleo "
        "local al reducir fugas de dinero y conflictos por reservas.",
    )
    add_p(doc, "Ambiental: menos papel y procesos 100% digitales.")
    add_p(
        doc,
        "Tecnológico: software propio (Flutter + NestJS + PostgreSQL/Supabase), automatización, analítica "
        "y notificaciones; infraestructura escalable por etapas (VPS, monitoreo de plataforma y plan "
        "gratuito controlado); dos verticales sobre la misma capacidad de desarrollo.",
    )

    add_h(doc, "17. Indicadores (orientativos)", 2)
    add_table(
        doc,
        ["Indicador", "Valor esperado"],
        [
            ["Empleos a crear", "1"],
            ["Eventos de mercadeo", "2"],
            ["Presupuesto / solicitado", "$73.538.010"],
            ["Producción Año 1 (suscripciones-mes)", f"{u1 + u2 + u3}"],
            ["Ventas Año 1", money(v1)],
        ],
    )

    add_h(doc, "18. Mapa de actores", 2)
    add_table(
        doc,
        ["Nombre", "Tipo", "Qué se requiere"],
        [
            ["SENA / Fondo Emprender", "Público", "Capital semilla y acompañamiento"],
            ["Wompi / bancos", "Privado", "Cobro de suscripciones"],
            ["Google Play / App Store", "Privado", "Distribución"],
            ["Cámara de Comercio 〔ciudad〕", "Público", "Constitución"],
            ["Proveedores nube (VPS)", "Privado", "Infraestructura"],
            ["Restaurantes / canchas", "Privado", "Clientes y validación"],
        ],
    )

    add_h(doc, "19. Asociatividad", 2)
    add_p(doc, "No aplica — presentación Individual.")

    add_h(doc, "HOJA 3 — Modelo financiero", 1)
    add_p(doc, "Única celda gris: tasa de descuento = 0,10 (10%). Déjala así.", bold=True)

    add_h(doc, "HOJA 4 — Resumen", 1)
    add_p(doc, "No se diligencia. Se autocompleta con TIR/VPN al llenar el Excel oficial.")

    add_h(doc, "Resultado financiero de ESTE llenado (referencia)", 1)
    add_p(
        doc,
        "Nota: la TIR/VPN oficiales las calcula la plantilla Excel. Esta tabla es la proyección "
        "coherente con los números de este Word (individual: sin impuesto de renta en la hoja).",
        size=10,
    )
    add_table(
        doc,
        ["Concepto (millones COP)", "A1", "A2", "A3", "A4", "A5"],
        [
            ["Ventas"] + [money_m(r["ventas"]) for r in er],
            ["− Materia prima (~6%)"] + [money_m(r["mp"]) for r in er],
            ["− Mano de obra"] + [money_m(r["mo"]) for r in er],
            ["− Costos fijos"] + [money_m(r["fijo"]) for r in er],
            ["− Permisos"] + [money_m(r["permiso"]) for r in er],
            ["= Utilidad bruta"] + [money_m(r["ub"]) for r in er],
            ["− Gastos admin/ventas"] + [money_m(r["ga"]) for r in er],
            ["= Utilidad neta"] + [money_m(r["un"]) for r in er],
        ],
    )
    add_p(doc, f"Inversión Año 0: −{money(INV)}")
    add_p(doc, f"Flujos (utilidad neta): " + " / ".join(money(r["un"]) for r in er))
    add_p(doc, f"VPN @ 10%: ≈ {money(vpn)}", bold=True)
    add_p(doc, f"TIR aproximada: ≈ {tir_pct:.0f}% (umbral 10%)", bold=True)
    add_p(doc, "VEREDICTO: PROYECTO VIABLE — con tracción real en TCF y Foody listo para escalar.", bold=True)

    add_h(doc, "Checklist antes de entregar al SENA", 1)
    for c in [
        "Reemplazar todos los 〔corchetes〕 con datos reales.",
        "Copiar valores solo a celdas grises del Excel oficial (no romper fórmulas).",
        "Verificar que punto 11 = 1 empleo y punto 12 = $73.538.010.",
        "Adjuntar evidencias: pantallas Foody, captura TCF, o constancia del cliente que paga.",
        "Constitución S.A.S. aparte (no va en el monto del Fondo).",
        "Revisar coherencia con el acompañante del Centro de Desarrollo Empresarial SENA.",
    ]:
        doc.add_paragraph(c, style="List Number")

    add_p(
        doc,
        "Documento generado para Foody APP / Fondo Emprender CREAR 2026. Uso: guía de diligenciamiento.",
        size=9,
    )

    doc.save(OUT)
    print(f"OK -> {OUT}")
    print(f"Ventas A1={v1} VPN={int(vpn)} TIR={tir_pct:.1f}%")
    for r in er:
        print(f"  A{r['anio']}: ventas={r['ventas']} un={r['un']}")


if __name__ == "__main__":
    build()

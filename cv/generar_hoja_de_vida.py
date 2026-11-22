# -*- coding: utf-8 -*-
"""Genera la hoja de vida de Javier Pinzón en .docx (una página, ATS-safe).

Uso:  python cv/generar_hoja_de_vida.py
Salida: cv/HojaDeVida_JavierPinzon_2026.docx

El texto entre ** ** sale en negrita. Editar las constantes y volver a ejecutar.
"""
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

AZUL = RGBColor(0x1F, 0x3A, 0x5F)
GRIS = RGBColor(0x50, 0x50, 0x50)
CUERPO = 9.7
SALIDA = Path(__file__).parent / "HojaDeVida_JavierPinzon_2026.docx"


def _borde_inferior(parrafo, color="1F3A5F", grosor="8"):
    pPr = parrafo._p.get_or_add_pPr()
    bordes = OxmlElement("w:pBdr")
    linea = OxmlElement("w:bottom")
    linea.set(qn("w:val"), "single")
    linea.set(qn("w:sz"), grosor)
    linea.set(qn("w:space"), "2")
    linea.set(qn("w:color"), color)
    bordes.append(linea)
    pPr.append(bordes)


def _enlace(parrafo, texto, url, tam=CUERPO):
    """Hipervínculo real (relación externa), no solo texto azul."""
    rid = parrafo.part.relate_to(
        url,
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
        is_external=True,
    )
    link = OxmlElement("w:hyperlink")
    link.set(qn("r:id"), rid)
    run = OxmlElement("w:r")
    rPr = OxmlElement("w:rPr")
    color = OxmlElement("w:color")
    color.set(qn("w:val"), "1F3A5F")
    sub = OxmlElement("w:u")
    sub.set(qn("w:val"), "single")
    sz = OxmlElement("w:sz")
    sz.set(qn("w:val"), str(int(tam * 2)))
    for el in (color, sub, sz):
        rPr.append(el)
    run.append(rPr)
    t = OxmlElement("w:t")
    t.text = texto
    run.append(t)
    link.append(run)
    parrafo._p.append(link)


def parrafo(doc, antes=0, despues=2, alineacion=None, interlineado=1.08):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(antes)
    p.paragraph_format.space_after = Pt(despues)
    p.paragraph_format.line_spacing = interlineado
    if alineacion is not None:
        p.alignment = alineacion
    return p


def rich(p, texto, tam=CUERPO, color=None):
    """Escribe texto aplicando negrita a los tramos marcados con **."""
    for i, tramo in enumerate(texto.split("**")):
        if not tramo:
            continue
        r = p.add_run(tramo)
        r.font.size = Pt(tam)
        r.font.bold = i % 2 == 1
        if color is not None:
            r.font.color.rgb = color
    return p


def seccion(doc, titulo):
    p = parrafo(doc, antes=8, despues=3)
    r = p.add_run(titulo.upper())
    r.font.size = Pt(10)
    r.font.bold = True
    r.font.color.rgb = AZUL
    _borde_inferior(p)
    return p


def vineta(doc, texto):
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.line_spacing = 1.08
    p.paragraph_format.left_indent = Cm(0.5)
    return rich(p, texto)


def cargo(doc, titulo, contexto, periodo, url=None, etiqueta_url="Ver proyecto"):
    p = parrafo(doc, antes=5, despues=0)
    r = p.add_run(titulo)
    r.font.bold = True
    r.font.size = Pt(10)
    r.font.color.rgb = AZUL
    sub = parrafo(doc, despues=2)
    r1 = sub.add_run(contexto)
    r1.font.size = Pt(CUERPO)
    r2 = sub.add_run(f"   ·   {periodo}")
    r2.font.size = Pt(9)
    r2.font.italic = True
    r2.font.color.rgb = GRIS
    if url:
        sub.add_run("   ").font.size = Pt(9)
        _enlace(sub, etiqueta_url, url, tam=9)
    return p


# --------------------------------------------------------------------------
# Contenido
# --------------------------------------------------------------------------
PERFIL = (
    "Tecnólogo en Análisis y Desarrollo de Software (SENA) con tres años construyendo aplicaciones "
    "web y móviles por cuenta propia, **dos de ellas en uso real por empresas**. Desarrollo "
    "**Foody**, un SaaS POS multi-restaurante con backend **NestJS + PostgreSQL** y cliente "
    "**Flutter** de 37 pantallas. Busco mi primera oportunidad dentro de un equipo de desarrollo: "
    "práctica, etapa productiva o rol junior."
)

HABILIDADES = [
    ("Backend", "NestJS, Node.js, TypeScript, API REST, autenticación JWT, RBAC con guards, "
                "WebSocket, tareas cron, Python/Flask"),
    ("Bases de datos", "PostgreSQL (transacciones, funciones, índices, Row Level Security), MySQL, "
                       "SQLite, Supabase, Firebase Firestore"),
    ("Móvil y frontend", "Flutter (Riverpod, GoRouter, Dio), Dart, JavaScript, HTML5, CSS3, React, "
                         "Bootstrap, diseño responsive"),
    ("DevOps e integraciones", "Docker y Docker Compose, GitHub Actions (CI), VPS Linux/Ubuntu, "
                               "Git, Wompi, FCM, OpenStreetMap"),
    ("Prácticas", "Arquitectura modular, pruebas con Jest y Supertest, documentación técnica, "
                  "trabajo por sprints"),
]

FOODY = [
    "**28 módulos de negocio, más de 200 endpoints REST y 85 migraciones SQL** versionadas: definí "
    "el backend como única fuente de verdad y Flutter como capa solo de presentación, sin cálculos "
    "financieros en el cliente.",
    "**Transacciones PostgreSQL atómicas** en el ciclo del pedido: stock, IVA, descuentos, propinas, "
    "caja y auditoría se mueven en una sola operación, evitando inconsistencias en hora pico.",
    "**Control de acceso en cadena de guards** (JWT, usuario activo, suscripción, rol, super admin) "
    "para 8 roles, con arquitectura multi-restaurante y multi-sucursal aislada por sede.",
    "**Integraciones completas**: pagos recurrentes con Wompi (checkout y webhook), push FCM con "
    "cola y cron, tiempo real con Supabase Realtime e impresión térmica vía agente Python sobre "
    "WebSocket.",
    "**37 pantallas Flutter multi-rol** (cliente, administrador, caja, cocina/KDS, mesero, "
    "domiciliario) con Riverpod, GoRouter y Dio, paneles analíticos y exportación PDF/CSV.",
    "**Docker Compose e integración continua en GitHub Actions** con scripts de verificación de "
    "extremo a extremo: 123 de 131 escenarios de negocio cubiertos y verificados.",
]

FREELANCE = [
    "**La Jugada** — plataforma de reservas de canchas sintéticas en Flutter + Firebase, **en "
    "producción** con una empresa del sector deportivo: reservas, sedes, horarios, roles de usuario "
    "y auditoría automática de modificaciones.",
    "**Software de inventario para pizzerías** en Python/Flask + MySQL: ventas, stock, alertas de "
    "inventario bajo y reportes que reemplazaron el control manual en hojas de cálculo.",
    "**Tienda online con panel administrativo**: e-commerce con sesiones de usuario, gestión de "
    "inventario y reportes de ventas en tiempo real.",
    "Trabajo directo con el cliente en todo el ciclo: levantamiento de requisitos, despliegue, "
    "capacitación y soporte posterior.",
]

MARKETING = [
    "Sitios corporativos y landing pages responsivas, automatización de procesos comerciales con "
    "soluciones web a medida y optimización de interfaces para mejorar la conversión.",
]

CIERRE = [
    ("Formación", "Tecnólogo en Análisis y Desarrollo de Software — SENA, Colombia"),
    ("Disponibilidad", "Inmediata, tiempo completo · presencial en Valledupar, remoto o con "
                       "disposición a reubicarme"),
    ("Vinculación", "Práctica o etapa productiva (contrato de aprendizaje SENA), rol junior o "
                    "contrato por proyecto"),
    ("Idiomas", "Español (nativo) · Inglés intermedio (lectura técnica fluida)"),
]


def construir():
    doc = Document()
    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(CUERPO)
    normal.paragraph_format.space_after = Pt(1.5)

    for s in doc.sections:
        s.top_margin = s.bottom_margin = Cm(1.2)
        s.left_margin = s.right_margin = Cm(1.5)

    # Encabezado
    nombre = parrafo(doc, despues=0, alineacion=WD_ALIGN_PARAGRAPH.CENTER)
    rn = nombre.add_run("JAVIER ENRIQUE PINZÓN AMEL")
    rn.font.size = Pt(18)
    rn.font.bold = True
    rn.font.color.rgb = AZUL

    sub = parrafo(doc, despues=1, alineacion=WD_ALIGN_PARAGRAPH.CENTER)
    rs = sub.add_run("Desarrollador Full-Stack  ·  Flutter · NestJS · PostgreSQL")
    rs.font.size = Pt(10.5)
    rs.font.color.rgb = GRIS

    contacto = parrafo(doc, despues=0, alineacion=WD_ALIGN_PARAGRAPH.CENTER)
    for i, txt in enumerate(["Valledupar, Colombia", "+57 304 473 7930",
                             "javierpinzon804@gmail.com"]):
        r = contacto.add_run(("  ·  " if i else "") + txt)
        r.font.size = Pt(9)
        r.font.color.rgb = GRIS
    for etiq, url in [
        ("LinkedIn", "https://www.linkedin.com/in/javier-enrique-pinzon-amel-731080264/"),
        ("GitHub", "https://github.com/javipin2"),
        ("Portafolio", "https://javipin2.github.io/portafolio_web/"),
    ]:
        sep = contacto.add_run("  ·  ")
        sep.font.size = Pt(9)
        sep.font.color.rgb = GRIS
        _enlace(contacto, etiq, url, tam=9)
    _borde_inferior(contacto, grosor="12")

    seccion(doc, "Perfil")
    rich(parrafo(doc, alineacion=WD_ALIGN_PARAGRAPH.JUSTIFY, despues=0), PERFIL)

    seccion(doc, "Habilidades técnicas")
    for etiq, valor in HABILIDADES:
        rich(parrafo(doc), f"**{etiq}:** {valor}")

    seccion(doc, "Proyecto principal")
    cargo(doc, "Foody — SaaS POS multi-restaurante",
          "Proyecto propio, desarrollado de extremo a extremo", "2026 – Actualidad")
    for b in FOODY:
        vineta(doc, b)

    seccion(doc, "Experiencia y proyectos")
    cargo(doc, "Desarrollador Full-Stack Freelance", "Clientes en Colombia", "2023 – Actualidad",
          url="https://canchas-la-jugada.web.app/", etiqueta_url="Ver La Jugada")
    for b in FREELANCE:
        vineta(doc, b)

    cargo(doc, "Desarrollador Web", "Grupo de marketing digital", "2023 – 2025",
          url="https://javipin2.github.io/MDTECH/MDTECH/index.html", etiqueta_url="Ver sitio")
    for b in MARKETING:
        vineta(doc, b)

    seccion(doc, "Formación y disponibilidad")
    for etiq, valor in CIERRE:
        rich(parrafo(doc), f"**{etiq}:** {valor}")

    doc.save(SALIDA)
    print(f"OK -> {SALIDA}")


if __name__ == "__main__":
    construir()

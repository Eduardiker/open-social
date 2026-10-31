# 📦 Content Hub - Repositorio de Contenidos de JALEO

Este directorio almacena todo el catálogo abierto de preguntas, categorías, retos y reglas para la aplicación **JALEO**.

La aplicación móvil consume estos archivos de dos formas:
1. **Modo Offline:** Vienen precargados en la carpeta de assets de la aplicación.
2. **Modo Online:** La app sincroniza automáticamente con este repositorio de GitHub consultando `index.json` para descargar nuevos paquetes sin necesidad de reinstalar la app.

---

## 📁 Estructura del Manifiesto `index.json`

El archivo [`index.json`](index.json) es el registro maestro que la app consulta para saber qué juegos y packs existen:

```json
{
  "name": "open_social_content",
  "version": "1.4.0",
  "description": "Repositorio oficial de contenidos para JALEO",
  "languages": ["es", "en"],
  "games": [
    {
      "id": "picolo_mode",
      "name": "Modo Picolo (Maldiciones)",
      "icon": "auto_awesome",
      "description": "Virus que duran turnos, duelos 1 vs 1, votaciones y reglas globales.",
      "packs": [
        {
          "id": "picolo_classic_es",
          "name": "Previa & Calentamiento",
          "language": "es",
          "rating": "teen",
          "version": 2,
          "file": "es/picolo_mode/classic.json"
        }
      ]
    }
  ]
}
```

---

## 🛠️ Validación Automática con GitHub Actions
Cada vez que alguien hace un Pull Request o envía cambios a `content_hub/`, el workflow [`.github/workflows/validate_content.yml`](../.github/workflows/validate_content.yml) comprueba automáticamente:
* Que todos los archivos `.json` tengan sintaxis válida.
* Que los archivos referenciados en `index.json` existan físicamente en las carpetas.

Para más detalles sobre cómo enviar nuevas preguntas, consulta la [Guía de Contribución](../CONTRIBUTING.md).

# ⚡ JALEO — Party Box & Drinking Games 🍻📱

<div align="center">

![JALEO App Icon](app/assets/icon/app_icon.jpg)

**La alternativa definitiva de código abierto a Social Gamebox y Picolo.**  
*10 Party Games en 1 • Modo Multijugador Web por QR (sin instalar apps) • Modo Picolo con Maldiciones • 100% Offline y Privado*

[![Build Android APK](https://github.com/Eduardiker/open-social/actions/workflows/build_apk.yml/badge.svg)](https://github.com/Eduardiker/open-social/actions/workflows/build_apk.yml)
[![Validate Content](https://github.com/Eduardiker/open-social/actions/workflows/validate_content.yml/badge.svg)](https://github.com/Eduardiker/open-social/actions/workflows/validate_content.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Community Driven](https://img.shields.io/badge/Community-100%25%20Open%20Content-00CEC9.svg)](CONTRIBUTING.md)

</div>

---

## 🌟 ¿Qué es JALEO?

**JALEO** es una plataforma móvil (*Pass & Play* y *Multijugador Web*) construida en **Flutter**, diseñada para revolucionar cualquier previa, fiesta o reunión con amigos. 

A diferencia de las apps comerciales que cobran suscripciones abusivas por desbloquear preguntas o requieren que todos tus amigos se descarguen una app pesada, **JALEO es libre, abierta y universal**:

1. **📱 Multijugador Web Inteligente:** El anfitrión crea la sala en su móvil y muestra un **Código QR**. Tus amigos apuntan la cámara de su móvil y juegan directamente desde su navegador (Safari o Chrome) **sin descargar nada**. Funciona tanto en la misma red WiFi (100% offline) como por código de sala Online P2P.
2. **🦠 Modo Picolo Auténtico:** Maldiciones y virus que duran turnos enteros (ej. *hablar como Batman*, *prohibido decir 'Sí/No'*), duelos 1 vs 1 cara a cara y reglas de mesa globales.
3. **🔒 Privacidad Garantizada:** Guarda tus preguntas picantes y privadas directamente en el almacenamiento local de tu móvil (`SharedPreferences`), sin enviarlas jamás a internet.
4. **📦 Contenido Comunitario Abierto:** Todas las preguntas, cartas y retos residen en formato JSON abierto en [`content_hub/`](content_hub/). ¡Cualquiera puede proponer preguntas y aparecerán en los móviles de todo el mundo!

---

## 🎮 Catálogo de Juegos Incluidos

| Juego | Mecánica | Modo de Juego |
| :--- | :--- | :--- |
| **✨ Modo Picolo** | Virus que duran rondas, duelos a muerte 1v1, reglas molestas y votaciones. Incluye 4 packs: *Previa*, *Fiesta*, *Picante +18* y *Sin Piedad*. | Pass & Play |
| **🕵️ El Impostor (*Undercover*)** | Palabras secretas en los móviles de los invitados (ej: Playa vs Piscina). Ronda de pistas y votación para pillar al impostor. | **Multijugador Web** |
| **💣 La Bomba (*Hot Bomb*)** | Di una palabra de la categoría y pasa el móvil antes de que el temporizador explote. | Pass & Play |
| **🗳️ Votación Secreta (*¿Quién es más probable?*)** | Cada amigo vota en secreto desde su pantalla; la app revela porcentajes y puñaladas en directo. | **Multijugador Web** |
| **🍻 Yo Nunca Live** | Tarjetas con respuestas simultáneas en cada móvil (*"¡Yo Sí!"* vs *"Yo Nunca"*). | **Multijugador Web** |
| **⚡ Verdad o Reto** | Confesiones comprometidas y desafíos físicos/sociales directos. | Pass & Play |
| **⚖️ ¿Qué prefieres?** | Dilemas imposibles con estadísticas de la comunidad. | Pass & Play |
| **💑 Modo Parejas** | Preguntas de sincronización íntima para saber si pensáis igual. | Pass & Play |
| **🎭 Fake It (Fíngelo)** | Acciones secretas con impostor por gestos y caras. | Pass & Play |
| **🎰 Ruleta de Castigos** | Generador de prendas y retos para los que pierdan en cualquier juego. | Pass & Play |

---

## 🌐 Cómo Funciona el Multijugador Web (Estilo Jackbox)

No hay que configurar servidores complejos ni pagar cuotas:

* **Opción 1: Red Local / WiFi Offline (0 ms de latencia)**  
  La propia app de Flutter arranca un micro-servidor HTTP y WebSocket local en el puerto `8080`. Funciona incluso en la playa o en una casa rural usando la **Zona Wi-Fi portátil (Hotspot)** de tu teléfono.
* **Opción 2: Online P2P (WebRTC con PeerJS)**  
  Genera un código de sala de 4 letras (ej: `FEST`). Los jugadores entran desde cualquier conexión 4G/5G a través de la WebApp sin necesidad de compartir red.

---

## ✍️ Cómo Colaborar y Añadir Nuevas Preguntas

¡Queremos que este sea el catálogo de party games más grande y divertido en español! No necesitas saber programar para contribuir:

👉 **Lee la [Guía de Contribución paso a paso (CONTRIBUTING.md)](CONTRIBUTING.md)**

* Puedes editar los archivos `.json` directamente desde tu navegador en GitHub.
* O si lo prefieres, simplemente abre un **[Issue con tus preguntas](../../issues/new?template=sugerir_preguntas.md)** y nosotros les daremos formato.

---

## 📲 Descargar la App (.APK para Android)

El repositorio cuenta con integración continua (**CI/CD**) automática mediante GitHub Actions:

1. Ve a la pestaña **[Actions](../../actions/workflows/build_apk.yml)** de este repositorio.
2. Selecciona la ejecución más reciente del flujo **Build Android APK**.
3. En la sección **Artifacts** al pie de la página, descarga el archivo `open-social-release-apk` e instálalo en tu dispositivo Android.

---

## 💻 Desarrollo Local

Si eres desarrollador y quieres modificar la app móvil:

```bash
# 1. Clonar el repositorio
git clone https://github.com/Eduardiker/open-social.git
cd open-social/app

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar en tu dispositivo o emulador
flutter run
```

---

## 📜 Licencia

Distribuido bajo la Licencia **MIT**. Consulta el archivo `LICENSE` para más información.
Desarrollado con ❤️ para que las mejores noches con amigos sean gratis y abiertas.

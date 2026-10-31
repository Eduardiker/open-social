# Open Social 📱🎉
> La alternativa de código abierto a las aplicaciones de party games (tipo *Social Gamebox*).

**Open Social** es una plataforma móvil (*Pass & Play*, 1 solo dispositivo) construida en **Flutter**, diseñada para reuniones y fiestas. La aplicación es completamente desacoplada de su contenido: **todas las preguntas, retos, mímicas e instrucciones residen en formato JSON abierto en GitHub**, permitiendo que cualquier persona de la comunidad proponga nuevos packs, traduzca a otros idiomas o corrija erratas mediante Pull Requests.

---

## 📂 Estructura del Proyecto

```plaintext
open_social/
├── app/                          # Código fuente de la aplicación móvil (Flutter)
│   ├── lib/
│   │   ├── core/                 # Temas, constantes y gestor de estado
│   │   ├── models/               # Modelos de packs y manifiesto
│   │   ├── services/             # Sincronización remota con GitHub y almacenamiento local
│   │   ├── screens/              # Pantallas principales (Home, Ajustes, Gestor de packs)
│   │   └── games/                # Motores de juego modulares:
│   │       ├── most_likely/      # ¿Quién es más probable?
│   │       ├── never_have_i_ever/# Yo Nunca
│   │       ├── truth_or_dare/    # Verdad o Reto
│   │       ├── fake_it/          # Fake It (Fíngelo)
│   │       ├── wrong_answers/    # Solo Respuestas Incorrectas
│   │       └── charades/         # Charadas en la frente (giroscopio)
│   └── pubspec.yaml
│
└── content_hub/                  # Repositorio de contenidos comunitarios (en GitHub)
    ├── index.json                # Manifiesto central con todos los packs y versiones
    └── es/                       # Contenidos en español
        ├── most_likely_to/
        ├── never_have_i_ever/
        ├── truth_or_dare/
        ├── fake_it/
        ├── wrong_answers_only/
        └── charades/
```

---

## 🎮 Catálogo inicial de Juegos

| Juego | Mecánica Pass & Play |
| :--- | :--- |
| **Fake It (Fíngelo)** | Cada jugador recibe una acción secreta en privado; el impostor finge no saber nada. Tras una cuenta atrás, ¡todos actúan a la vez! |
| **¿Quién es más probable?** | Sale una afirmación atrevida o cómica; cuenta atrás y todos señalan simultáneamente. |
| **Yo Nunca** | Tarjetas temáticas (Clásico, Fiesta, Picante). Si lo has hecho, bebes o pierdes una vida. |
| **Verdad o Reto** | Selección directa entre la confesión sincera o un desafío físico/social. |
| **Solo Respuestas Incorrectas** | Preguntas obvias a contrarreloj. Si dices la verdad, pierdes. |
| **Charadas en la Frente** | Ponte el móvil en la frente; inclínalo hacia abajo para acertar o arriba para pasar. |

---

## 🌐 Filosofía Open Source & Contribuciones

* **Cero backend obligatorio:** La app funciona 100% offline con packs base precargados.
* **Sincronización directa con GitHub:** La app consulta el manifiesto `index.json` en GitHub mediante `raw.githubusercontent.com` y descarga las actualizaciones en la base de datos local del móvil.
* **Cómo contribuir contenido:** Basta con clonar el repositorio, añadir preguntas a los archivos `.json` existentes o crear nuevos packs temáticos, y abrir una Pull Request.

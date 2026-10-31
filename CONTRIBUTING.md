# 🍻 Guía de Contribución para JALEO (Party Box)

¡Bienvenido/a a la comunidad de **JALEO**! Este proyecto es 100% de código abierto y está diseñado para que **cualquier persona pueda añadir preguntas, retos, cartas de Maldiciones o nuevas categorías sin necesidad de saber programar**.

Todas las preguntas de la app están organizadas en archivos de texto sencillos (**JSON**) dentro de la carpeta [`content_hub/`](content_hub/). Cuando añades preguntas aquí, ¡aparecerán automáticamente en los teléfonos de todos los usuarios del mundo al actualizar!

---

## 🚀 Cómo añadir preguntas en 3 sencillos pasos (Sin instalar nada)

No necesitas instalar Git ni Flutter. Puedes hacerlo todo directamente desde la web de GitHub en tu navegador:

### Paso 1: Encuentra el juego que quieres ampliar
Entra en la carpeta del idioma correspondiente, por ejemplo [`content_hub/es/`](content_hub/es/):
* 🦠 **Maldiciones & Duelos (Virus Party)**: `content_hub/es/picolo_mode/` (`classic.json`, `party.json`, `spicy.json`, `bar.json`)
* 💣 **La Bomba**: `content_hub/es/hot_bomb/categories.json`
* 👥 **¿Quién es más probable?**: `content_hub/es/most_likely_to/classic.json`
* 🍺 **Yo Nunca**: `content_hub/es/never_have_i_ever/` (`classic.json`, `party.json`)
* ⚡ **Verdad o Reto**: `content_hub/es/truth_or_dare/classic.json`
* ⚖️ **¿Qué prefieres?**: `content_hub/es/would_you_rather/classic.json`
* 🎰 **Ruleta de Castigos / Prendas**: `content_hub/es/penalties/penalties.json`
* 🕵️ **Fake It / Fíngelo**: `content_hub/es/fake_it/classic.json`

### Paso 2: Edita el archivo en GitHub
1. Haz clic en el archivo que quieras mejorar.
2. Pulsa en el icono del **lápiz ✏️ ("Edit this file")** en la esquina superior derecha.
3. Añade tus nuevas preguntas siguiendo el formato (mira los ejemplos más abajo).
4. Asegúrate de poner una coma `,` entre cada elemento.

### Paso 3: Envía tus preguntas (Pull Request)
1. Al final de la página, escribe un título breve en la caja de commit (ej: *"Añadidas 10 preguntas picantes a Maldiciones & Duelos"*).
2. Selecciona **"Create a new branch for this commit and start a pull request"**.
3. Pulsa el botón verde **"Propose changes"** y luego **"Create pull request"**.
4. ¡Listo! El sistema automático de GitHub verificará la sintaxis y nosotros revisaremos e incluiremos tus preguntas en la siguiente actualización.

---

## 🧩 Variables Mágicas Disponibles

En muchos juegos (como Maldiciones & Duelos o Verdad o Reto), puedes hacer que el juego sea dinámico usando los nombres de los jugadores de la fiesta:

* `{p1}`: Se sustituye aleatoriamente por el nombre de un jugador (ej. *"Laura"*).
* `{p2}`: Se sustituye por otro jugador diferente de la partida (ej. *"Marcos"*).
* `{turns}`: En las cartas de Virus, se sustituye por el número de rondas que dura la maldición (ej. *"3"*).

**Ejemplo:**
```json
"{p1} debe darle un abrazo de 10 segundos a {p2} o beber 3 tragos."
```

---

## 📋 Formatos de Ejemplo por Tipo de Juego

### 1. Cartas de Maldiciones & Duelos (`picolo_mode`)
El Maldiciones & Duelos soporta varios tipos de cartas:
```json
// Virus / Maldición con duración de turnos:
{
  "type": "virus",
  "title": "🦠 VIRUS: PALABRAS PROHIBIDAS",
  "text": "{p1} no puede decir las palabras 'SÍ' ni 'NO' durante {turns} rondas. ¡Quien le haga caer le manda beber!",
  "duration": 4,
  "target": "p1"
}

// Duelo 1 vs 1 entre dos jugadores:
{
  "type": "duel",
  "title": "⚔️ DUELO: MIRADAS ASESINAS",
  "text": "Duelo a muerte entre {p1} y {p2}: el primero que parpadee o sonría bebe 3 tragos o paga prenda.",
  "p1": true,
  "p2": true
}

// Regla general para toda la mesa:
{
  "type": "rule",
  "title": "📜 REGLA DE MESA: EL CODO",
  "text": "Queda prohibido señalar con el dedo. A partir de ahora solo se señala con el codo. Quien falle, bebe.",
  "duration": 5
}

// Votación grupal inmediata:
{
  "type": "vote",
  "title": "🗳️ VOTACIÓN: EL MÁS FALSO",
  "text": "A la de 3, todos señalan al que mejor disimula cuando alguien le cae mal. ¡El más votado bebe 3 tragos!"
}
```

### 2. Yo Nunca (`never_have_i_ever`)
```json
{
  "items": [
    "Yo nunca he fingido no ver a alguien por la calle para no tener que saludar.",
    "Yo nunca he enviado una captura de pantalla a la misma persona de la que estaba hablando por error."
  ]
}
```

### 3. ¿Quién es más probable? (`most_likely_to`)
```json
{
  "items": [
    "¿Quién tiene más probabilidades de acabar viviendo en otro país por un impulso?",
    "¿Quién tardaría menos en vender a sus amigos por 1 millón de euros?"
  ]
}
```

### 4. La Bomba (`hot_bomb`)
```json
{
  "categories": [
    "Cosas que huelen mal",
    "Marcas de cerveza",
    "Excusas para llegar tarde al trabajo o a clase"
  ]
}
```

### 5. ¿Qué prefieres? (`would_you_rather`)
```json
{
  "dilemmas": [
    {
      "option_a": "Saber la fecha exacta de tu muerte",
      "option_b": "Saber la causa de tu muerte pero no cuándo ocurrirá",
      "stats_a": 42,
      "stats_b": 58
    }
  ]
}
```

---

## 🏷️ Clasificación de Intensidad (Ratings)
Cada pack tiene una etiqueta en su cabecera:
* `"rating": "all-ages"`: Apto para toda la familia, sin referencias sexuales ni alcohol.
* `"rating": "teen"`: Divertido para previas y fiestas juveniles (salseo ligero, chistes, retos).
* `"rating": "18+"`: Contenido picante, preguntas íntimas, confesiones sexuales o juegos con alcohol.

---

## 💡 ¿No quieres tocar código JSON? ¡Abre un Issue!
Si prefieres simplemente pasarnos una lista de preguntas en texto plano:
1. Ve a la pestaña **[Issues](../../issues)** de este repositorio.
2. Haz clic en **"New Issue"**.
3. Pega tus preguntas y dinos para qué juego son. Nosotros nos encargaremos de darles formato e integrarlas.

¡Gracias por ayudar a que las fiestas de todo el mundo sean mucho más divertidas con **JALEO**! 🎉🍻
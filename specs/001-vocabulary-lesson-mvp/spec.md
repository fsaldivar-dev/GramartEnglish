# Feature Specification: Vocabulary Lesson MVP

**Feature Branch**: `001-vocabulary-lesson-mvp`

**Created**: 2026-05-12

**Status**: Draft

**Input**: User description: "MVP de lección de vocabulario para GramartEnglish. App macOS para estudiantes de inglés. Lección en formato quiz de opción múltiple. Vocabulario proviene de listas predefinidas por nivel CEFR (A1, A2, B1, B2, C1, C2). El sistema usa un LLM local (vía RAG) para generar ejemplos de uso y definiciones contextuales por palabra."

## Clarifications

### Session 2026-05-12

- Q: ¿Qué algoritmo se usa para elegir las 10 palabras de cada lección? → A: Mezcla priorizada: ~50 % palabras nuevas del nivel, ~30 % falladas recientes, ~20 % refuerzo de palabras dominadas hace tiempo. SRS completo (estilo SM-2/Anki) y otros métodos de aprendizaje quedan explícitamente fuera del MVP como exploración futura.
- Q: ¿Cómo elige el usuario su nivel CEFR en el primer arranque? → A: Mini-test de placement de ~10 palabras de varios niveles que estima el nivel automáticamente. El usuario puede ajustar el nivel después si no le encaja.
- Q: ¿Cómo se despliega el backend Node.js? → A: Embebido y supervisado por la app macOS: la app lanza el proceso Node.js como child process al abrirse y lo cierra al salir. El usuario nunca interactúa con el backend directamente.
- Q: ¿Cuál es la versión mínima de macOS y el hardware objetivo? → A: macOS 14 (Sonoma) o superior, exclusivamente Apple Silicon (M1 o superior), con 16 GB de RAM mínimos. Intel y configuraciones con menos RAM quedan fuera del MVP.
- Q: ¿Cómo se aborda la privacidad y el posible uso por menores? → A: Diseño privacy-first totalmente local: sin login, sin cuenta, sin nombre del usuario, sin telemetría, sin analytics, sin recolección de datos personales. Ningún dato sale del dispositivo. Esto evita compliance regulatorio (COPPA/GDPR-K) al no recoger información personal.

## User Scenarios & Testing *(mandatory)*

### User Story 0 - Determinar el nivel CEFR del usuario en el primer arranque (Priority: P1)

En el primer arranque, la app pregunta al usuario si quiere estimar su nivel con un mini-test (~10 palabras de niveles mezclados A1–C2). El usuario responde y la app calcula su nivel CEFR estimado y lo guarda como nivel actual. Más adelante puede ajustarlo manualmente desde ajustes.

**Why this priority**: Sin un nivel correcto, las lecciones se sienten muy fáciles o muy difíciles y el usuario abandona. Es parte del bucle P1.

**Independent Test**: Instalación limpia → completar el mini-test → la app muestra el nivel estimado y permite empezar una lección de ese nivel.

**Acceptance Scenarios**:

1. **Given** primer arranque sin nivel guardado, **When** el usuario abre la app, **Then** ve una pantalla de bienvenida que explica el mini-test y un botón "Empezar".
2. **Given** el usuario está en el mini-test, **When** responde las ~10 preguntas, **Then** la app calcula y muestra el nivel CEFR estimado con una explicación corta y un botón "Aceptar y empezar lección".
3. **Given** el usuario no está de acuerdo con la estimación, **When** abre Ajustes, **Then** puede cambiar manualmente el nivel a cualquier otro entre A1 y C2.

---

### User Story 1 - Tomar una lección de vocabulario por nivel (Priority: P1)

Un estudiante abre la app, elige su nivel CEFR (A1–C2) y comienza una lección. La app le presenta una serie de preguntas de opción múltiple, una por palabra: muestra una palabra en inglés y cuatro definiciones posibles. El estudiante elige una; la app marca correcto/incorrecto, registra el resultado y avanza a la siguiente palabra. Al terminar la lección ve un resumen (cuántas acertó, cuáles falló).

**Why this priority**: Es el bucle central del producto. Sin esto, no hay aplicación. Entrega valor inmediato (el estudiante practica vocabulario) y permite validar el flujo macOS ↔ backend ↔ datos.

**Independent Test**: Puede probarse de extremo a extremo sin RAG ni LLM: usando definiciones estáticas de la lista CEFR, el usuario puede completar una lección completa de 10 preguntas y ver su resultado.

**Acceptance Scenarios**:

1. **Given** el usuario abre la app por primera vez, **When** selecciona el nivel "A2" y pulsa "Empezar lección", **Then** la app muestra la primera pregunta con la palabra, 4 opciones de definición, y un contador de progreso (1 de 10).
2. **Given** el usuario está respondiendo una pregunta, **When** selecciona la opción correcta, **Then** la app marca visualmente la respuesta como correcta, revela la definición canónica, y habilita el botón "Siguiente".
3. **Given** el usuario está respondiendo una pregunta, **When** selecciona una opción incorrecta, **Then** la app marca la respuesta como incorrecta, muestra cuál era la correcta, y registra el fallo para revisión.
4. **Given** el usuario terminó las 10 preguntas, **When** llega a la pantalla final, **Then** ve su puntuación (X/10), la lista de palabras falladas y un botón "Repetir lección" / "Nueva lección".

---

### User Story 2 - Ver ejemplo de uso y definición contextual generados por IA (Priority: P2)

Durante o después de una pregunta, el estudiante puede pedir "muéstrame un ejemplo de uso" o "explícame el significado en este contexto". La app consulta el LLM local mediante el pipeline RAG (que se apoya en la lista CEFR y materiales asociados) y devuelve: (a) 2–3 frases de ejemplo reales con la palabra, (b) una definición adaptada al nivel del usuario.

**Why this priority**: Es lo que diferencia a GramartEnglish de un quiz tradicional. Pero la User Story 1 puede entregarse y validarse sin esta funcionalidad, así que se trata como capa de valor sobre el MVP.

**Independent Test**: Puede probarse aislando una sola palabra: dado un término "ephemeral" del nivel B2, el sistema debe devolver 2–3 ejemplos en inglés y una definición de ~1–2 líneas en menos de 1.5 segundos al primer token, sin alucinaciones evidentes (las frases deben contener la palabra exacta o una flexión válida).

**Acceptance Scenarios**:

1. **Given** el usuario ha respondido una pregunta (correcta o incorrectamente), **When** pulsa "Ver ejemplos", **Then** la app muestra 2–3 frases en inglés con la palabra resaltada y la fuente/grado de confianza visible.
2. **Given** el usuario está en la pantalla de revisión post-lección, **When** selecciona una palabra fallada, **Then** la app muestra la definición contextualizada al nivel CEFR seleccionado y un ejemplo de uso.
3. **Given** el modelo LLM local no está disponible (Ollama caído o sin red local), **When** el usuario pulsa "Ver ejemplos", **Then** la app muestra un mensaje claro ("Ejemplos IA no disponibles ahora — definición estática mostrada") y degrada a la definición de la lista CEFR.

---

### User Story 3 - Persistir progreso y reanudar entre sesiones (Priority: P3)

El estudiante cierra la app a mitad de lección o entre lecciones. Al volver a abrirla, ve su nivel actual, las palabras que ya domina, las que falla repetidamente y puede continuar donde se quedó.

**Why this priority**: Importante para retención de usuarios y para que el sistema mejore su selección de palabras, pero el MVP puede entregar valor en una sola sesión sin esto.

**Independent Test**: Puede probarse abriendo la app, completando una lección, cerrándola y reabriéndola. La app debe mostrar el resultado anterior y la palabra siguiente que toca practicar.

**Acceptance Scenarios**:

1. **Given** el usuario completó al menos una lección, **When** cierra y reabre la app, **Then** la pantalla inicial muestra "Última lección: X/10" y un botón "Continuar con A2 — lección 2".
2. **Given** el usuario cerró la app a mitad de una lección, **When** la reabre, **Then** la app ofrece "Reanudar lección" o "Empezar nueva".
3. **Given** el usuario lleva varias lecciones, **When** ve su panel de palabras, **Then** distingue las palabras dominadas (acertadas 2 veces seguidas) de las que requieren práctica.

---

### Edge Cases

- **Lista CEFR vacía o no disponible**: si los datos del nivel seleccionado no cargan, la app debe mostrar un mensaje claro y no permitir iniciar la lección.
- **LLM lento o sin respuesta**: si el LLM tarda más de un umbral configurable (p. ej. 5 s), la app debe permitir cancelar y caer al texto estático sin congelar la UI.
- **Palabra con varios significados**: el RAG debe escoger el significado pertinente al nivel/contexto; si hay ambigüedad real, la definición debe indicar "uso más común en nivel X".
- **Usuario sin selección de nivel**: la primera vez, la app debe forzar la selección de nivel antes de permitir iniciar una lección.
- **Repetición excesiva**: el sistema no debe repetir la misma palabra dentro de una misma lección de 10.
- **Internet ausente**: como Ollama corre local, la app debe funcionar sin internet siempre que el backend Node.js y Ollama estén accesibles localmente.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: En el primer arranque, el sistema MUST guiar al usuario por un mini-test de placement de ~10 preguntas (palabras de niveles A1–C2 en proporciones balanceadas) y estimar automáticamente su nivel CEFR inicial a partir del resultado. El usuario MUST poder ajustar manualmente su nivel después en una pantalla de ajustes si la estimación no le encaja.
- **FR-002**: El sistema MUST ofrecer lecciones de exactamente 10 preguntas (configurable internamente pero fijo en MVP) de tipo opción múltiple con 4 alternativas.
- **FR-003**: El sistema MUST presentar para cada pregunta una palabra del nivel seleccionado y 4 definiciones, de las cuales exactamente 1 es correcta y 3 son distractores plausibles del mismo nivel.
- **FR-004**: El sistema MUST registrar por cada respuesta: palabra, opción elegida, opción correcta, marca de acierto/fallo y timestamp.
- **FR-005**: El sistema MUST mostrar al final de cada lección un resumen con puntuación, palabras falladas y la opción de repetir o iniciar nueva lección.
- **FR-006**: El sistema MUST proveer listas curadas de vocabulario para los 6 niveles CEFR, con al menos suficientes palabras para 5 lecciones por nivel en el MVP (≥ 50 palabras por nivel).
- **FR-007**: Cada palabra de la lista CEFR MUST incluir: forma base, definición canónica, categoría gramatical y nivel.
- **FR-008**: El sistema MUST permitir al usuario solicitar "ejemplos de uso" para una palabra, devolviendo 2–3 frases generadas por el LLM local vía RAG, en menos de 1.5 s al primer token bajo condiciones normales.
- **FR-009**: El sistema MUST permitir al usuario solicitar "definición contextual" para una palabra, devolviendo una explicación adaptada al nivel CEFR seleccionado.
- **FR-010**: El RAG MUST utilizar la lista CEFR y materiales asociados como fuente de contexto; el LLM no debe generar definiciones sin grounding contra esa fuente.
- **FR-011**: El sistema MUST degradar elegantemente cuando el LLM local no esté disponible: las funciones de quiz siguen operativas usando definiciones canónicas; las funciones IA muestran un aviso claro.
- **FR-012**: El sistema MUST persistir entre sesiones: nivel del usuario, historial de lecciones, palabras dominadas y palabras a reforzar.
- **FR-013**: El sistema MUST evitar repetir la misma palabra dentro de una lección de 10.
- **FR-013a**: El sistema MUST construir cada lección con una mezcla priorizada de palabras: aproximadamente 50 % palabras nuevas del nivel CEFR seleccionado (nunca vistas por el usuario), 30 % palabras falladas recientemente, 20 % palabras dominadas a refrescar (no vistas hace varias lecciones). Las proporciones se aplican como objetivo, no como cuota estricta cuando alguna categoría no tiene material suficiente (en cuyo caso se rellena con palabras nuevas del nivel).
- **FR-013b**: Métodos de aprendizaje más avanzados (repetición espaciada completa tipo SRS/SM-2, intervalos por palabra, factor de facilidad por palabra, modelos de olvido) quedan FUERA del MVP y se exploran como features futuras.
- **FR-014**: El sistema MUST funcionar sin conexión a internet siempre que los componentes locales (backend, LLM) estén disponibles.
- **FR-015**: La app MUST cumplir los principios de accesibilidad de la constitución del proyecto (VoiceOver, navegación por teclado, Dynamic Type, contraste).
- **FR-016**: El sistema MUST registrar logs estructurados de cada solicitud al LLM con identificador de correlación, palabra consultada y tiempo de respuesta, para diagnóstico.
- **FR-017**: El sistema MUST tratar el progreso del usuario como dato sensible: almacenado localmente con permisos de usuario y nunca enviado a servicios externos.
- **FR-018**: El sistema MUST operar bajo un modelo privacy-first: sin login, sin cuenta, sin solicitar nombre / email / edad / identidad del usuario, sin telemetría, sin analytics, sin envío de eventos a servicios externos. Ningún dato del usuario (progreso, respuestas, palabras, logs) MUST salir del dispositivo bajo ninguna circunstancia en el MVP.
- **FR-019**: Cualquier futura adición de telemetría, analytics o sincronización requiere una enmienda explícita a la constitución y una pantalla de consentimiento; no es alcance del MVP.

### Key Entities

- **User**: representa al estudiante de forma totalmente anónima. Atributos: identificador local opaco (UUID, sin relación con datos personales), nivel CEFR actual, fecha de creación local, preferencias de accesibilidad. NO se almacenan nombre, email, edad ni ningún identificador personal.
- **CEFRLevel**: A1 / A2 / B1 / B2 / C1 / C2.
- **VocabularyWord**: palabra del corpus curado. Atributos: forma base, categoría gramatical, definición canónica, nivel CEFR, ejemplos canónicos opcionales.
- **Lesson**: una sesión de 10 preguntas. Atributos: usuario, nivel, fecha, lista de preguntas, puntuación final, estado (en curso / completada / abandonada).
- **Question**: una pregunta dentro de una lección. Atributos: palabra, 4 opciones, índice de la correcta, respuesta del usuario, acierto/fallo, tiempo de respuesta.
- **WordMastery**: estado del usuario respecto a una palabra. Atributos: aciertos consecutivos, fallos totales, último visto, marca de "dominada".
- **RAGSource**: documento o entrada usada por el RAG (lista CEFR, materiales asociados). Atributos: identificador, contenido, embedding, versión del esquema de índice.
- **AIGeneration**: resultado de una llamada al LLM. Atributos: palabra consultada, tipo (ejemplo / definición contextual), texto generado, fuentes RAG citadas, modelo, latencia, correlación id.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un estudiante puede completar su primera lección de 10 preguntas en menos de **4 minutos** desde el primer arranque de la app.
- **SC-002**: El **90 %** de los estudiantes de prueba completan al menos una lección sin solicitar ayuda externa al producto.
- **SC-003**: La app entrega la primera ficha/pregunta visible en pantalla en menos de **2 segundos** tras el arranque en frío en el Mac mínimo soportado.
- **SC-004**: Cuando el estudiante solicita "ejemplos de uso", la primera frase aparece en pantalla en menos de **1.5 segundos** en condiciones nominales.
- **SC-005**: Al menos el **80 %** de las palabras de cada nivel CEFR tienen definiciones canónicas revisadas antes del lanzamiento del MVP.
- **SC-006**: El **100 %** de las funciones de quiz (selección de nivel, preguntas, resultado) operan correctamente cuando el LLM local está caído.
- **SC-007**: En pruebas con 5 estudiantes objetivo, el **80 %** califica la experiencia como "útil o muy útil" para repasar vocabulario.
- **SC-008**: La tasa de palabras "dominadas" (acertadas 2 veces seguidas) sobre palabras vistas crece de forma monótona a lo largo de 5 lecciones en al menos el **70 %** de los usuarios de prueba.

## Assumptions

- El producto se entrega como **app nativa macOS**; iOS, Web y Windows quedan fuera del MVP.
- **Plataforma mínima soportada**: macOS 14 (Sonoma) o superior, exclusivamente Apple Silicon (M1, M2, M3 o superior) con un mínimo de **16 GB de RAM**. Macs Intel y configuraciones con menos RAM quedan explícitamente fuera del MVP. Las pruebas de rendimiento (SC-003, SC-004) se ejecutan contra esta línea base (Mac mínima: M1 / 16 GB).
- El backend Node.js se distribuye **embebido** dentro del bundle de la app macOS: la app lo lanza como child process al abrirse y lo termina al cerrarse. El usuario no instala ni administra el backend por separado. No se contempla despliegue en la nube en el MVP.
- El sistema MUST detectar si el puerto local del backend ya está ocupado al arrancar y elegir otro automáticamente o reportar un error claro; el usuario nunca debe ver un crash silencioso.
- Ollama es el runtime LLM local; no se permitirán proveedores LLM en la nube en el MVP (alineado con la constitución).
- El MVP cubre únicamente **vocabulario**; gramática y comprensión contextual amplia quedan fuera de alcance (features futuras).
- El usuario es un único estudiante local por instalación; multi-usuario y sincronización en la nube quedan fuera del MVP.
- Las listas CEFR se construirán a partir de fuentes públicas (p. ej. listados CEFR-J u Oxford 3000/5000) con curación manual para el MVP.
- El RAG indexa las listas CEFR + un set inicial de ejemplos canónicos por palabra; añadir más fuentes (libros, lecturas) es trabajo posterior.
- La app asume que el modelo Ollama elegido cabe y corre con latencia aceptable en la Mac mínima soportada (asunción a validar en `/speckit-plan`).
- Internet no es requerido tras la instalación inicial.

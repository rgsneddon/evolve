/// Scenario-specific discourse construal strings (PART THREE + interventions).
const discourseStringsEn = <String, String>{
  'discourse_protest_context':
      'Discourse construal: collective-disorder circulation around {subject}{topic_suffix}.',
  'discourse_protest_action_1':
      '{agent}: Publish ward-level incident timelines for {subject}{topic_suffix} — separate lawful assembly from disorder with verified arrest/charge data. {shear_hook}',
  'discourse_protest_action_2':
      '{agent}: Convene community liaison with protest organisers and affected businesses on {subject}{topic_suffix} within 14 days. {resistance_hook}',
  'discourse_protest_action_3':
      '{agent}: Announce differentiated enforcement criteria for {subject}{topic_suffix} with a public compliance tracker. {flow_hook}',
  'discourse_protest_intervention_1':
      'Publish granular protest incident data for {subject}{topic_suffix} — peaceful vs. disorder counts by ward.',
  'discourse_protest_intervention_2':
      'Stand up independent community forums where grievance narratives on {subject} are recorded, not dismissed.',
  'discourse_protest_intervention_3':
      'Pair enforcement updates on {subject} with named liaison officers and published response-time targets.',
  'discourse_protest_intervention_4':
      'Review public-order messaging on {subject}{topic_suffix} for selective-condemnation bias (σ).',
  'discourse_official_context':
      'Discourse construal: institutional framing compressing {subject}{topic_suffix}.',
  'discourse_official_action_1':
      '{agent}: Issue a clause-by-clause public response to {subject}{topic_suffix}, citing evidence for each condemnation line. {shear_hook}',
  'discourse_official_action_2':
      '{agent}: Hold a press briefing allowing follow-up questions on {subject}{topic_suffix} — not pre-approved questions only. {resistance_hook}',
  'discourse_official_action_3':
      '{agent}: Commit to a 30-day review of messaging on {subject}{topic_suffix} with an independent fact-check partner. {flow_hook}',
  'discourse_official_intervention_1':
      'Release timestamped evidence packets for each claim in {subject}{topic_suffix}.',
  'discourse_official_intervention_2':
      'Open a structured Q&A channel on {subject} for journalists and affected communities.',
  'discourse_official_intervention_3':
      'Audit institutional drag (Iτ) where {resistance_snip} slows corrective response.',
  'discourse_official_intervention_4':
      'Differentiate peaceful civic expression from criminal acts in all {subject} communications.',
  'discourse_economic_context':
      'Discourse construal: macro-economic and labour-pressure circulation on {subject}{topic_suffix}.',
  'discourse_economic_action_1':
      '{agent}: Publish cost-impact tables for {subject}{topic_suffix} showing who bears disruption vs. relief. {shear_hook}',
  'discourse_economic_action_2':
      '{agent}: Broker a timed negotiation on {subject}{topic_suffix} with unions, employers, and rider/user groups. {resistance_hook}',
  'discourse_economic_action_3':
      '{agent}: Announce phased reopening or relief steps for {subject}{topic_suffix} with measurable milestones. {flow_hook}',
  'discourse_economic_intervention_1':
      'Publish daily disruption metrics for {subject}{topic_suffix} with cost borne by households and firms.',
  'discourse_economic_intervention_2':
      'Convene a tri-party table on {subject} — labour, management, and service users — with published minutes.',
  'discourse_economic_intervention_3':
      'Address stated resistance: {resistance_snip}',
  'discourse_economic_intervention_4':
      'Preserve nuance in rider/user messaging: {flow_snip}',
  'discourse_electoral_context':
      'Discourse construal: electoral vortex polarising {subject}{topic_suffix}.',
  'discourse_electoral_action_1':
      '{agent}: Release a voter-facing fact sheet on {subject}{topic_suffix} separating campaign claims from verified records. {shear_hook}',
  'discourse_electoral_action_2':
      '{agent}: Host a neutral-format public forum on {subject}{topic_suffix} with equal time for competing narratives. {resistance_hook}',
  'discourse_electoral_action_3':
      '{agent}: Publish audit-ready timelines for {subject}{topic_suffix} decisions before voting windows close. {flow_hook}',
  'discourse_electoral_intervention_1':
      'Publish claim-vs-record matrices for {subject}{topic_suffix} with source links.',
  'discourse_electoral_intervention_2':
      'Fund neutral civic-information sessions on {subject} in high-shear districts.',
  'discourse_electoral_intervention_3':
      'Reduce institutional drag on electoral transparency for {subject}.',
  'discourse_electoral_intervention_4':
      'Track trust-transport (Jμ) gaps across voter segments on {subject}.',
  'discourse_trust_context':
      'Discourse construal: narrative-lens compression on trust around {subject}{topic_suffix}.',
  'discourse_trust_action_1':
      '{agent}: Acknowledge where {subject}{topic_suffix} framing compressed nuance — publish a corrective narrative map. {shear_hook}',
  'discourse_trust_action_2':
      '{agent}: Invite critics of {subject}{topic_suffix} to a structured evidence exchange, not a single podium. {resistance_hook}',
  'discourse_trust_action_3':
      '{agent}: Deploy differentiated outreach on {subject}{topic_suffix} for groups whose trust transport diverges. {flow_hook}',
  'discourse_trust_intervention_1':
      'Map two-tier perception gaps on {subject}{topic_suffix} with quoted community sources.',
  'discourse_trust_intervention_2':
      'Replace blanket condemnation lines on {subject} with event-level differentiation.',
  'discourse_trust_intervention_3':
      'Address institutional scepticism: {resistance_snip}',
  'discourse_trust_intervention_4':
      'Strengthen differentiated messaging: {flow_snip}',
  'discourse_accountability_context':
      'Discourse construal: accountability pressure on {subject}{topic_suffix}.',
  'discourse_accountability_action_1':
      '{agent}: Hold an open press briefing on {subject}{topic_suffix} with published decision criteria and timelines. {shear_hook}',
  'discourse_accountability_action_2':
      '{agent}: Commission an independent summary of institutional process around {subject}{topic_suffix}. {resistance_hook}',
  'discourse_accountability_action_3':
      '{agent}: Set binding review dates for {subject}{topic_suffix} with public progress markers. {flow_hook}',
  'discourse_accountability_intervention_1':
      'Publish decision criteria and timelines for {subject}{topic_suffix} before speculation hardens.',
  'discourse_accountability_intervention_2':
      'Independent process review for {subject} — scope, witnesses, and publication date fixed.',
  'discourse_accountability_intervention_3':
      'Reduce procedural drag where {resistance_snip}',
  'discourse_accountability_intervention_4':
      'Maintain transparent status updates on {subject} through the review window.',
  'discourse_open_context':
      'Discourse construal: open-ended ω scenario on {subject}{topic_suffix}.',
  'discourse_open_action_1':
      '{agent}: Convene a scenario-specific public session on {subject}{topic_suffix} anchored to the stated ω question. {shear_hook}',
  'discourse_open_action_2':
      '{agent}: Map stakeholder positions on {subject}{topic_suffix} from the supplied σ/Iτ inputs. {resistance_hook}',
  'discourse_open_action_3':
      '{agent}: Publish time-bound next steps on {subject}{topic_suffix} reflecting stated Jμ nuance. {flow_hook}',
  'discourse_open_intervention_1':
      'Ground public updates on {subject}{topic_suffix} in the user-stated ω question: {vortex_snip}',
  'discourse_open_intervention_2':
      'Address shear bias where stated: {shear_snip}',
  'discourse_open_intervention_3':
      'Work through institutional resistance: {resistance_snip}',
  'discourse_open_intervention_4':
      'Preserve trust-transport nuance: {flow_snip}',
  'discourse_open_support_action_1':
      '{agent}: Convene a public progress review on {subject}{topic_suffix} to sustain covariant continuity. {shear_hook}',
  'discourse_open_support_action_2':
      '{agent}: Publish constructive milestones on {subject}{topic_suffix} with community co-design. {resistance_hook}',
  'discourse_open_support_action_3':
      '{agent}: Reinforce differentiated trust transport on {subject}{topic_suffix} across stakeholder groups. {flow_hook}',
  'discourse_open_support_intervention_1':
      'Sustain progressive momentum on {subject}{topic_suffix} with published cohesion indicators.',
  'discourse_open_support_intervention_2':
      'Co-design outreach on {subject} with groups where Jμ transport is strongest.',
  'discourse_open_support_intervention_3':
      'Reduce residual friction: {resistance_snip}',
  'discourse_open_support_intervention_4':
      'Amplify stated nuance: {flow_snip}',
};

const discourseStringsEs = <String, String>{
  'discourse_protest_context':
      'Construal del discurso: circulación de desorden colectivo en torno a {subject}{topic_suffix}.',
  'discourse_protest_action_1':
      '{agent}: Publicar cronologías de incidentes por distrito para {subject}{topic_suffix} — separar asamblea lícita del desorden con datos verificados de detenciones/cargos. {shear_hook}',
  'discourse_protest_action_2':
      '{agent}: Convocar enlace comunitario con organizadores de protestas y comercios afectados sobre {subject}{topic_suffix} en 14 días. {resistance_hook}',
  'discourse_protest_action_3':
      '{agent}: Anunciar criterios de aplicación diferenciados para {subject}{topic_suffix} con un registro público de cumplimiento. {flow_hook}',
  'discourse_protest_intervention_1':
      'Publicar datos granulares de incidentes de protesta para {subject}{topic_suffix} — recuentos pacíficos vs. desorden por distrito.',
  'discourse_protest_intervention_2':
      'Crear foros comunitarios independientes donde las narrativas de queja sobre {subject} se registren, no se descarten.',
  'discourse_protest_intervention_3':
      'Emparejar actualizaciones de orden público sobre {subject} con oficiales de enlace nombrados y plazos de respuesta publicados.',
  'discourse_protest_intervention_4':
      'Revisar el mensaje de orden público sobre {subject}{topic_suffix} por sesgo de condena selectiva (σ).',
  'discourse_official_context':
      'Construal del discurso: encuadre institucional que comprime {subject}{topic_suffix}.',
  'discourse_official_action_1':
      '{agent}: Emitir una respuesta pública cláusula por cláusula sobre {subject}{topic_suffix}, citando evidencia para cada línea de condena. {shear_hook}',
  'discourse_official_action_2':
      '{agent}: Convocar una rueda de prensa con preguntas de seguimiento sobre {subject}{topic_suffix} — no solo preguntas preaprobadas. {resistance_hook}',
  'discourse_official_action_3':
      '{agent}: Comprometerse a una revisión de 30 días del mensaje sobre {subject}{topic_suffix} con un socio independiente de verificación de hechos. {flow_hook}',
  'discourse_official_intervention_1':
      'Publicar paquetes de evidencia con marcas de tiempo para cada afirmación en {subject}{topic_suffix}.',
  'discourse_official_intervention_2':
      'Abrir un canal estructurado de preguntas y respuestas sobre {subject} para periodistas y comunidades afectadas.',
  'discourse_official_intervention_3':
      'Auditar el arrastre institucional (Iτ) donde {resistance_snip} ralentiza la respuesta correctiva.',
  'discourse_official_intervention_4':
      'Diferenciar expresión cívica pacífica de actos delictivos en todas las comunicaciones sobre {subject}.',
  'discourse_economic_context':
      'Construal del discurso: circulación de presión macroeconómica y laboral sobre {subject}{topic_suffix}.',
  'discourse_economic_action_1':
      '{agent}: Publicar tablas de impacto de costos para {subject}{topic_suffix} mostrando quién asume la disrupción frente al alivio. {shear_hook}',
  'discourse_economic_action_2':
      '{agent}: Mediar una negociación con plazo sobre {subject}{topic_suffix} con sindicatos, empleadores y grupos de usuarios. {resistance_hook}',
  'discourse_economic_action_3':
      '{agent}: Anunciar pasos de reapertura o alivio por fases para {subject}{topic_suffix} con hitos medibles. {flow_hook}',
  'discourse_economic_intervention_1':
      'Publicar métricas diarias de disrupción para {subject}{topic_suffix} con el costo asumido por hogares y empresas.',
  'discourse_economic_intervention_2':
      'Convocar una mesa tripartita sobre {subject} — sindicatos, gestión y usuarios — con actas publicadas.',
  'discourse_economic_intervention_3':
      'Abordar la resistencia indicada: {resistance_snip}',
  'discourse_economic_intervention_4':
      'Preservar el matiz en el mensaje a usuarios: {flow_snip}',
  'discourse_electoral_context':
      'Construal del discurso: vórtice electoral que polariza {subject}{topic_suffix}.',
  'discourse_electoral_action_1':
      '{agent}: Publicar una hoja informativa para votantes sobre {subject}{topic_suffix} separando afirmaciones de campaña de registros verificados. {shear_hook}',
  'discourse_electoral_action_2':
      '{agent}: Organizar un foro público en formato neutral sobre {subject}{topic_suffix} con tiempo igual para narrativas competidoras. {resistance_hook}',
  'discourse_electoral_action_3':
      '{agent}: Publicar cronologías listas para auditoría sobre decisiones de {subject}{topic_suffix} antes del cierre de ventanas electorales. {flow_hook}',
  'discourse_electoral_intervention_1':
      'Publicar matrices afirmación-vs-registro para {subject}{topic_suffix} con enlaces a fuentes.',
  'discourse_electoral_intervention_2':
      'Financiar sesiones neutrales de información cívica sobre {subject} en distritos de alta cizalla.',
  'discourse_electoral_intervention_3':
      'Reducir el arrastre institucional sobre transparencia electoral para {subject}.',
  'discourse_electoral_intervention_4':
      'Seguir brechas de transporte de confianza (Jμ) entre segmentos de votantes sobre {subject}.',
  'discourse_trust_context':
      'Construal del discurso: compresión de lente narrativa sobre la confianza en {subject}{topic_suffix}.',
  'discourse_trust_action_1':
      '{agent}: Reconocer dónde el encuadre de {subject}{topic_suffix} comprimió matices — publicar un mapa narrativo correctivo. {shear_hook}',
  'discourse_trust_action_2':
      '{agent}: Invitar a críticos de {subject}{topic_suffix} a un intercambio estructurado de evidencia, no a un solo podio. {resistance_hook}',
  'discourse_trust_action_3':
      '{agent}: Desplegar alcance diferenciado sobre {subject}{topic_suffix} para grupos cuyo transporte de confianza diverge. {flow_hook}',
  'discourse_trust_intervention_1':
      'Mapear brechas de percepción de dos niveles sobre {subject}{topic_suffix} con fuentes comunitarias citadas.',
  'discourse_trust_intervention_2':
      'Reemplazar líneas de condena general sobre {subject} con diferenciación a nivel de evento.',
  'discourse_trust_intervention_3':
      'Abordar el escepticismo institucional: {resistance_snip}',
  'discourse_trust_intervention_4':
      'Fortalecer mensajes diferenciados: {flow_snip}',
  'discourse_accountability_context':
      'Construal del discurso: presión de rendición de cuentas sobre {subject}{topic_suffix}.',
  'discourse_accountability_action_1':
      '{agent}: Convocar una rueda de prensa abierta sobre {subject}{topic_suffix} con criterios de decisión y plazos publicados. {shear_hook}',
  'discourse_accountability_action_2':
      '{agent}: Encargar un resumen independiente del proceso institucional en torno a {subject}{topic_suffix}. {resistance_hook}',
  'discourse_accountability_action_3':
      '{agent}: Fijar fechas de revisión vinculantes para {subject}{topic_suffix} con marcadores de progreso públicos. {flow_hook}',
  'discourse_accountability_intervention_1':
      'Publicar criterios de decisión y plazos para {subject}{topic_suffix} antes de que la especulación se consolide.',
  'discourse_accountability_intervention_2':
      'Revisión independiente del proceso para {subject} — alcance, testigos y fecha de publicación fijados.',
  'discourse_accountability_intervention_3':
      'Reducir el arrastre procedimental donde {resistance_snip}',
  'discourse_accountability_intervention_4':
      'Mantener actualizaciones transparentes sobre {subject} durante la ventana de revisión.',
  'discourse_open_context':
      'Construal del discurso: escenario ω abierto sobre {subject}{topic_suffix}.',
  'discourse_open_action_1':
      '{agent}: Convocar una sesión pública específica del escenario sobre {subject}{topic_suffix} anclada a la pregunta ω planteada. {shear_hook}',
  'discourse_open_action_2':
      '{agent}: Mapear posiciones de las partes sobre {subject}{topic_suffix} a partir de las entradas σ/Iτ suministradas. {resistance_hook}',
  'discourse_open_action_3':
      '{agent}: Publicar próximos pasos con plazo sobre {subject}{topic_suffix} reflejando el matiz Jμ indicado. {flow_hook}',
  'discourse_open_intervention_1':
      'Basar actualizaciones públicas sobre {subject}{topic_suffix} en la pregunta ω indicada: {vortex_snip}',
  'discourse_open_intervention_2':
      'Abordar el sesgo de cizalla indicado: {shear_snip}',
  'discourse_open_intervention_3':
      'Trabajar la resistencia institucional: {resistance_snip}',
  'discourse_open_intervention_4':
      'Preservar el matiz de transporte de confianza: {flow_snip}',
  'discourse_open_support_action_1':
      '{agent}: Convocar una revisión pública de progreso sobre {subject}{topic_suffix} para sostener la continuidad covariante. {shear_hook}',
  'discourse_open_support_action_2':
      '{agent}: Publicar hitos constructivos sobre {subject}{topic_suffix} con co-diseño comunitario. {resistance_hook}',
  'discourse_open_support_action_3':
      '{agent}: Reforzar el transporte de confianza diferenciado sobre {subject}{topic_suffix} entre grupos de partes interesadas. {flow_hook}',
  'discourse_open_support_intervention_1':
      'Sostener el momento progresivo sobre {subject}{topic_suffix} con indicadores de cohesión publicados.',
  'discourse_open_support_intervention_2':
      'Co-diseñar alcance sobre {subject} con grupos donde el transporte Jμ es más fuerte.',
  'discourse_open_support_intervention_3':
      'Reducir fricción residual: {resistance_snip}',
  'discourse_open_support_intervention_4':
      'Amplificar el matiz indicado: {flow_snip}',
};

/// Duplicate action/intervention keys as mitigate variants (same de-escalation content).
Map<String, String> leanMitigateVariants(Map<String, String> src) {
  final out = <String, String>{};
  for (final e in src.entries) {
    final k = e.key;
    if (RegExp(r'_action_\d+$').hasMatch(k)) {
      out[k.replaceFirst('_action_', '_mitigate_action_')] = e.value;
    } else if (RegExp(r'_intervention_\d+$').hasMatch(k)) {
      out[k.replaceFirst('_intervention_', '_mitigate_intervention_')] = e.value;
    }
  }
  return out;
}

/// Shared UI / binding / construct strings — English.
const sharedInfoStringsEn = <String, String>{
  'bind_region': 'Region: {region}',
  'bind_topic': 'Topic: {topic}',
  'bind_vortex': 'ω: {value}',
  'bind_shear': 'σ: {value}',
  'bind_resistance': 'Iτ: {value}',
  'bind_flow': 'Jμ: {value}',
  'bind_shear_observed': 'σ: observed {scs}/100',
  'bind_resistance_observed': 'Iτ: observed {scs}/100',
  'bind_flow_observed': 'Jμ: observed {scs}/100',
  'bind_continuum_lean': 'THE CONTINUUM: {lean} ({reg}% regressive / {prog}% progressive)',
  'continuum_understand_mitigate':
      'Scenario reads {lean} ({reg}% regressive / {prog}% progressive) — recommendations reduce scenario likelihood and repair cohesion; do not amplify regressive momentum.',
  'continuum_understand_support':
      'Scenario reads {lean} ({reg}% regressive / {prog}% progressive) — recommendations sustain progressive cohesion.',
  'lean_aim_mitigate':
      'Aim: reduce likelihood of {subject}, not amplify REGRESSIVE momentum.',
  'lean_aim_support': 'Aim: sustain PROGRESSIVE cohesion on {subject}.',
  'lean_aim_mitigate_short': '(mitigation — reduce scenario likelihood)',
  'lean_aim_support_short': '(support — sustain progressive cohesion)',
  'part3_headline_pct_mitigate':
      'PART THREE — Mitigation actions for the {agent} (REGRESSIVE lean)',
  'part3_headline_pct_support':
      'PART THREE — Support actions for the {agent} (PROGRESSIVE lean)',
  'part3_headline_scs_mitigate':
      'PART THREE — Cohesion repair for the {agent} (REGRESSIVE lean)',
  'part3_headline_scs_support':
      'PART THREE — Cohesion sustainment for the {agent} (PROGRESSIVE lean)',
  'part3_target_pct_mitigate':
      'Mitigation target: ~{current}% → ~{projected}% on "{subject}" (reduce, not raise)',
  'part3_target_pct_support':
      'Support target: ~{current}% → ~{projected}% on "{subject}"',
  'part3_target_scs_mitigate':
      'Cohesion repair: SCS ~{current} → {min}–{max} on "{subject}" (counter REGRESSIVE lean)',
  'part3_target_scs_support':
      'Cohesion sustainment: SCS ~{current} → {min}–{max} on "{subject}"',
  'part3_impact_pct_mitigate':
      'These steps may lower the estimate for "{subject}" from ~{current}% toward ~{projected}% — mitigation, not amplification.',
  'part3_impact_pct_support':
      'These steps may raise the constructive estimate for "{subject}" from ~{current}% toward ~{projected}%.',
  'part3_impact_scs_mitigate':
      'These steps may raise cohesion from ~{current}/100 toward {min}–{max}/100 to counter REGRESSIVE momentum.',
  'part3_impact_scs_support':
      'These steps may sustain cohesion from ~{current}/100 toward {min}–{max}/100 within 3 months.',
  'construct_vortex_name': 'Vortex',
  'construct_shear_name': 'Shear',
  'construct_resistance_name': 'Resistance',
  'construct_flow_name': 'Flow',
  'construct_continuum_name': 'Continuum',
  'construct_vortex_hint':
      'ω circulation variable relative to your posed question — elite framing, authority compression…',
  'construct_shear_hint': 'Bias — polarized framing, grievance, two-tier perception…',
  'construct_resistance_hint': 'Opposing bias — institutional inertia, skepticism…',
  'construct_flow_hint': 'Nuances — trust transport, covariant continuity…',
  'label_baseline_delta_fmt': 'Baseline → refined: {from} → {to} (Δ {delta})',
  'label_levers_count': '{n} {label}',
  'grok_title': 'Grok',
  'grok_subtitle': '@grok · Chronoflux observational reply',
  'grok_copied': 'Copied @grok reply',
  'report_copied': 'Report copied',
  'advisory_percent_headline': 'POSE YOUR SCENARIO QUESTION — THEN ADD ω/σ/Iτ/Jμ VARIABLES',
  'advisory_percent_step1':
      'Type your base question in POSE YOUR QUESTION HERE — this anchors every calculation.',
  'advisory_percent_step2':
      'Fill Vortex (ω), Shear (σ), Resistance (Iτ), and Flow (Jμ) — or turn on Grok construal to auto-fill them.',
  'advisory_percent_step2_grok':
      'Grok construal fills ω/σ/Iτ/Jμ from your question as you type. Edit any field to override.',
  'advisory_percent_step3': 'Tap Calculate percent chance for your Chronoflux probability.',
  'advisory_cohesion_headline':
      "PASTE A LINK — I'LL LET YOU KNOW THE SOCIAL COHESION SCORE OF THIS NARRATIVE",
  'advisory_cohesion_step1':
      'Paste a news article, statement, or narrative URL in the link field below.',
  'advisory_cohesion_step2':
      'Tap Read narrative from link — Evolve loads the page text into POSE YOUR QUESTION HERE.',
  'advisory_cohesion_step3':
      'Fill ω/σ/Iτ/Jμ manually, or turn on Grok construal, then Calculate social cohesion score.',
  'advisory_cohesion_step3_grok':
      'Grok construal fills ω/σ/Iτ/Jμ from the loaded narrative. Review, then Calculate social cohesion score.',
  'link_label': 'Narrative URL',
  'link_hint': 'https://example.com/article…',
  'link_fetch': 'Read narrative from link',
  'link_fetching': 'Reading narrative from link…',
  'link_fetched': 'Narrative loaded — review your posed question below and calculate SCS.',
  'link_error_invalid': 'Enter a valid http or https link.',
  'link_error_fetch':
      'Could not read that link. Check the URL, try https://, or paste the narrative text into your posed question manually.',
  'link_error_empty':
      'That page returned little or no readable text (often a login wall or JavaScript-only layout). Paste the article text into your posed question manually.',
  'link_error_blocked':
      'That site blocked automated reading (common on X/Twitter and paywalled pages). Paste the narrative text into your posed question manually.',
  'link_error_x_auth':
      'Sign in with X (Grok construal bar) to read posts from X/Twitter, then try the link again.',
  'link_fetched_connect_x':
      'Narrative loaded. Sign in with X to fill ω/σ/Iτ/Jμ from the text, then calculate.',
};

/// Shared UI / binding / construct strings — Spanish.
const sharedInfoStringsEs = <String, String>{
  'bind_region': 'Región: {region}',
  'bind_topic': 'Tema: {topic}',
  'bind_vortex': 'ω: {value}',
  'bind_shear': 'σ: {value}',
  'bind_resistance': 'Iτ: {value}',
  'bind_flow': 'Jμ: {value}',
  'bind_shear_observed': 'σ: observado {scs}/100',
  'bind_resistance_observed': 'Iτ: observado {scs}/100',
  'bind_flow_observed': 'Jμ: observado {scs}/100',
  'bind_continuum_lean': 'EL CONTINUUM: {lean} ({reg}% regresivo / {prog}% progresivo)',
  'continuum_understand_mitigate':
      'El escenario se lee {lean} ({reg}% regresivo / {prog}% progresivo) — las recomendaciones reducen la probabilidad del escenario y reparan la cohesión; no amplificar el momento regresivo.',
  'continuum_understand_support':
      'El escenario se lee {lean} ({reg}% regresivo / {prog}% progresivo) — las recomendaciones sostienen la cohesión progresiva.',
  'lean_aim_mitigate':
      'Objetivo: reducir la probabilidad de {subject}, no amplificar el momento REGRESIVO.',
  'lean_aim_support': 'Objetivo: sostener la cohesión PROGRESIVA en {subject}.',
  'lean_aim_mitigate_short': '(mitigación — reducir probabilidad del escenario)',
  'lean_aim_support_short': '(apoyo — sostener cohesión progresiva)',
  'part3_headline_pct_mitigate':
      'PARTE TRES — Acciones de mitigación para el/la {agent} (inclinación REGRESIVA)',
  'part3_headline_pct_support':
      'PARTE TRES — Acciones de apoyo para el/la {agent} (inclinación PROGRESIVA)',
  'part3_headline_scs_mitigate':
      'PARTE TRES — Reparación de cohesión para el/la {agent} (inclinación REGRESIVA)',
  'part3_headline_scs_support':
      'PARTE TRES — Sostenimiento de cohesión para el/la {agent} (inclinación PROGRESIVA)',
  'part3_target_pct_mitigate':
      'Objetivo de mitigación: ~{current}% → ~{projected}% en "{subject}" (reducir, no elevar)',
  'part3_target_pct_support':
      'Objetivo de apoyo: ~{current}% → ~{projected}% en "{subject}"',
  'part3_target_scs_mitigate':
      'Reparación de cohesión: SCS ~{current} → {min}–{max} en "{subject}" (contrarrestar inclinación REGRESIVA)',
  'part3_target_scs_support':
      'Sostenimiento de cohesión: SCS ~{current} → {min}–{max} en "{subject}"',
  'part3_impact_pct_mitigate':
      'Estos pasos pueden reducir la estimación de "{subject}" de ~{current}% hacia ~{projected}% — mitigación, no amplificación.',
  'part3_impact_pct_support':
      'Estos pasos pueden elevar la estimación constructiva de "{subject}" de ~{current}% hacia ~{projected}%.',
  'part3_impact_scs_mitigate':
      'Estos pasos pueden elevar la cohesión de ~{current}/100 hacia {min}–{max}/100 para contrarrestar el momento REGRESIVO.',
  'part3_impact_scs_support':
      'Estos pasos pueden sostener la cohesión de ~{current}/100 hacia {min}–{max}/100 en 3 meses.',
  'construct_vortex_name': 'Vórtice',
  'construct_shear_name': 'Cizalla',
  'construct_resistance_name': 'Resistencia',
  'construct_flow_name': 'Flujo',
  'construct_continuum_name': 'Continuum',
  'construct_vortex_hint':
      'Variable ω de circulación relativa a su pregunta planteada — encuadre de élite, compresión de autoridad…',
  'construct_shear_hint': 'Sesgo — encuadre polarizado, queja, percepción de dos niveles…',
  'construct_resistance_hint': 'Sesgo opuesto — inercia institucional, escepticismo…',
  'construct_flow_hint': 'Matices — transporte de confianza, continuidad covariante…',
  'label_baseline_delta_fmt': 'Base → refinado: {from} → {to} (Δ {delta})',
  'label_levers_count': '{n} {label}',
  'grok_title': 'Grok',
  'grok_subtitle': '@grok · respuesta observacional Chronoflux',
  'grok_copied': 'Respuesta @grok copiada',
  'report_copied': 'Informe copiado',
  'advisory_percent_headline': 'PLANTEE SU PREGUNTA EN EL VÓRTICE CHRONOFLUX',
  'advisory_percent_step1':
      'Escriba cualquier pregunta ω o escenario mundial en el campo Vórtice (ω) abajo.',
  'advisory_percent_step2':
      'Rellene Vórtice (ω), Cizalla (σ), Resistencia (Iτ) y Flujo (Jμ) — o active Grok construal.',
  'advisory_percent_step2_grok':
      'Grok construal rellena ω/σ/Iτ/Jμ desde su pregunta. Edite cualquier campo para anular.',
  'advisory_percent_step3': 'Pulse Calcular probabilidad para su estimación Chronoflux.',
  'advisory_cohesion_headline':
      'PEGUE UN ENLACE — LE DIRÉ LA PUNTUACIÓN DE COHESIÓN SOCIAL DE ESTA NARRATIVA',
  'advisory_cohesion_step1':
      'Pegue la URL de un artículo, declaración o narrativa en el campo de enlace abajo.',
  'advisory_cohesion_step2':
      'Pulse Leer narrativa del enlace — Evolve extrae el texto de la página al Vórtice (ω).',
  'advisory_cohesion_step3':
      'Rellene ω/σ/Iτ/Jμ manualmente o active Grok construal, luego calcule la cohesión social.',
  'advisory_cohesion_step3_grok':
      'Grok construal rellena ω/σ/Iτ/Jμ desde la narrativa cargada. Revise y calcule.',
  'link_label': 'URL de la narrativa',
  'link_hint': 'https://ejemplo.com/articulo…',
  'link_fetch': 'Leer narrativa del enlace',
  'link_fetching': 'Leyendo narrativa del enlace…',
  'link_fetched': 'Narrativa cargada — revise ω abajo y calcule SCS.',
  'link_error_invalid': 'Introduzca un enlace http o https válido.',
  'link_error_fetch':
      'No se pudo leer el enlace. Compruebe la URL, pruebe https://, o pegue el texto en su pregunta planteada.',
  'link_error_empty':
      'La página devolvió poco o ningún texto legible (muro de acceso o solo JavaScript). Pegue el artículo en su pregunta planteada.',
  'link_error_blocked':
      'El sitio bloqueó la lectura automática (común en X/Twitter y páginas de pago). Pegue la narrativa en su pregunta planteada.',
  'link_error_x_auth':
      'Inicie sesión con X (barra Grok construal) para leer publicaciones de X/Twitter y vuelva a intentar el enlace.',
  'link_fetched_connect_x':
      'Narrativa cargada. Inicie sesión con X para completar ω/σ/Iτ/Jμ desde el texto y calcule.',
};

const sharedInfoStringsFr = <String, String>{
  'bind_region': 'Région : {region}',
  'bind_topic': 'Sujet : {topic}',
  'bind_vortex': 'ω : {value}',
  'bind_shear': 'σ : {value}',
  'bind_resistance': 'Iτ : {value}',
  'bind_flow': 'Jμ : {value}',
  'bind_shear_observed': 'σ : observé {scs}/100',
  'bind_resistance_observed': 'Iτ : observé {scs}/100',
  'bind_flow_observed': 'Jμ : observé {scs}/100',
  'construct_vortex_name': 'Vortex',
  'construct_shear_name': 'Cisaillement',
  'construct_resistance_name': 'Résistance',
  'construct_flow_name': 'Flux',
  'construct_continuum_name': 'Continuum',
  'construct_vortex_hint': 'Toute question ou scénario ω…',
  'construct_shear_hint': 'Biais — cadrage polarisé, grief, perception à deux niveaux…',
  'construct_resistance_hint': 'Biais opposé — inertie institutionnelle, scepticisme…',
  'construct_flow_hint': 'Nuances — transport de confiance, continuité covariante…',
  'label_baseline_delta_fmt': 'Base → affiné : {from} → {to} (Δ {delta})',
  'label_levers_count': '{n} {label}',
  'grok_title': 'Grok',
  'grok_subtitle': '@grok · réponse observationnelle Chronoflux',
  'grok_copied': 'Réponse @grok copiée',
  'report_copied': 'Rapport copié',
};

const sharedInfoStringsDe = <String, String>{
  'bind_region': 'Region: {region}',
  'bind_topic': 'Thema: {topic}',
  'bind_vortex': 'ω: {value}',
  'bind_shear': 'σ: {value}',
  'bind_resistance': 'Iτ: {value}',
  'bind_flow': 'Jμ: {value}',
  'bind_shear_observed': 'σ: beobachtet {scs}/100',
  'bind_resistance_observed': 'Iτ: beobachtet {scs}/100',
  'bind_flow_observed': 'Jμ: beobachtet {scs}/100',
  'construct_vortex_name': 'Wirbel',
  'construct_shear_name': 'Scherung',
  'construct_resistance_name': 'Widerstand',
  'construct_flow_name': 'Fluss',
  'construct_continuum_name': 'Kontinuum',
  'construct_vortex_hint': 'Beliebige ω-Frage oder Szenario…',
  'construct_shear_hint': 'Bias — polarisierte Rahmung, Beschwerde…',
  'construct_resistance_hint': 'Gegen-Bias — institutionelle Trägheit…',
  'construct_flow_hint': 'Nuancen — Vertrauenstransport…',
  'label_baseline_delta_fmt': 'Basis → verfeinert: {from} → {to} (Δ {delta})',
  'label_levers_count': '{n} {label}',
  'grok_title': 'Grok',
  'grok_subtitle': '@grok · Chronoflux-Beobachtungsantwort',
  'grok_copied': '@grok-Antwort kopiert',
  'report_copied': 'Bericht kopiert',
};

const sharedInfoStringsPt = <String, String>{
  'bind_region': 'Região: {region}',
  'bind_topic': 'Tópico: {topic}',
  'bind_vortex': 'ω: {value}',
  'bind_shear': 'σ: {value}',
  'bind_resistance': 'Iτ: {value}',
  'bind_flow': 'Jμ: {value}',
  'bind_shear_observed': 'σ: observado {scs}/100',
  'bind_resistance_observed': 'Iτ: observado {scs}/100',
  'bind_flow_observed': 'Jμ: observado {scs}/100',
  'construct_vortex_name': 'Vórtice',
  'construct_shear_name': 'Cisalhamento',
  'construct_resistance_name': 'Resistência',
  'construct_flow_name': 'Fluxo',
  'construct_continuum_name': 'Continuum',
  'construct_vortex_hint': 'Qualquer pergunta ou cenário ω…',
  'construct_shear_hint': 'Viés — enquadramento polarizado…',
  'construct_resistance_hint': 'Viés oposto — inércia institucional…',
  'construct_flow_hint': 'Nuances — transporte de confiança…',
  'label_baseline_delta_fmt': 'Base → refinado: {from} → {to} (Δ {delta})',
  'label_levers_count': '{n} {label}',
  'grok_title': 'Grok',
  'grok_subtitle': '@grok · resposta observacional Chronoflux',
  'grok_copied': 'Resposta @grok copiada',
  'report_copied': 'Relatório copiado',
};

const sharedInfoStringsAr = <String, String>{
  'bind_region': 'المنطقة: {region}',
  'bind_topic': 'الموضوع: {topic}',
  'bind_vortex': 'ω: {value}',
  'bind_shear': 'σ: {value}',
  'bind_resistance': 'Iτ: {value}',
  'bind_flow': 'Jμ: {value}',
  'bind_shear_observed': 'σ: مرصود {scs}/100',
  'bind_resistance_observed': 'Iτ: مرصود {scs}/100',
  'bind_flow_observed': 'Jμ: مرصود {scs}/100',
  'construct_vortex_name': 'الدوامة',
  'construct_shear_name': 'القص',
  'construct_resistance_name': 'المقاومة',
  'construct_flow_name': 'التدفق',
  'construct_continuum_name': 'الcontinuum',
  'construct_vortex_hint': 'أي سؤال أو سيناريو ω…',
  'construct_shear_hint': 'التحيز — تأطير مستقطب…',
  'construct_resistance_hint': 'تحيز معاكس — جمود مؤسسي…',
  'construct_flow_hint': 'الفروق — نقل الثقة…',
  'label_baseline_delta_fmt': 'الأساس → المكرر: {from} → {to} (Δ {delta})',
  'label_levers_count': '{n} {label}',
  'grok_title': 'Grok',
  'grok_subtitle': '@grok · رد Chronoflux الملاحظي',
  'grok_copied': 'تم نسخ رد @grok',
  'report_copied': 'تم نسخ التقرير',
};

const sharedInfoStringsZh = <String, String>{
  'bind_region': '地区：{region}',
  'bind_topic': '主题：{topic}',
  'bind_vortex': 'ω：{value}',
  'bind_shear': 'σ：{value}',
  'bind_resistance': 'Iτ：{value}',
  'bind_flow': 'Jμ：{value}',
  'bind_shear_observed': 'σ：观测 {scs}/100',
  'bind_resistance_observed': 'Iτ：观测 {scs}/100',
  'bind_flow_observed': 'Jμ：观测 {scs}/100',
  'construct_vortex_name': '涡旋',
  'construct_shear_name': '剪切',
  'construct_resistance_name': '阻力',
  'construct_flow_name': '流动',
  'construct_continuum_name': '连续体',
  'construct_vortex_hint': '任何 ω 问题或情景…',
  'construct_shear_hint': '偏见 — 两极化框架…',
  'construct_resistance_hint': '对立偏见 — 制度惯性…',
  'construct_flow_hint': '细微差别 — 信任传输…',
  'label_baseline_delta_fmt': '基线 → 精炼：{from} → {to}（Δ {delta}）',
  'label_levers_count': '{n} {label}',
  'grok_title': 'Grok',
  'grok_subtitle': '@grok · Chronoflux 观测回复',
  'grok_copied': '已复制 @grok 回复',
  'report_copied': '报告已复制',
};

const sharedInfoStringsHi = <String, String>{
  'bind_region': 'क्षेत्र: {region}',
  'bind_topic': 'विषय: {topic}',
  'bind_vortex': 'ω: {value}',
  'bind_shear': 'σ: {value}',
  'bind_resistance': 'Iτ: {value}',
  'bind_flow': 'Jμ: {value}',
  'bind_shear_observed': 'σ: अवलोकित {scs}/100',
  'bind_resistance_observed': 'Iτ: अवलोकित {scs}/100',
  'bind_flow_observed': 'Jμ: अवलोकित {scs}/100',
  'construct_vortex_name': 'वॉर्टेक्स',
  'construct_shear_name': 'शीयर',
  'construct_resistance_name': 'प्रतिरोध',
  'construct_flow_name': 'प्रवाह',
  'construct_continuum_name': 'कंटिन्यूअम',
  'construct_vortex_hint': 'कोई भी ω प्रश्न या परिदृश्य…',
  'construct_shear_hint': 'पूर्वाग्रह — ध्रुवीकृत फ्रेमिंग…',
  'construct_resistance_hint': 'विपरीत पूर्वाग्रह — संस्थागत जड़ता…',
  'construct_flow_hint': 'बारीकियाँ — विश्वास परिवहन…',
  'label_baseline_delta_fmt': 'आधार → परिष्कृत: {from} → {to} (Δ {delta})',
  'label_levers_count': '{n} {label}',
  'grok_title': 'Grok',
  'grok_subtitle': '@grok · Chronoflux अवलोकन उत्तर',
  'grok_copied': '@grok उत्तर कॉपी किया गया',
  'report_copied': 'रिपोर्ट कॉपी की गई',
};

const sharedInfoStringsJa = <String, String>{
  'bind_region': '地域：{region}',
  'bind_topic': 'トピック：{topic}',
  'bind_vortex': 'ω：{value}',
  'bind_shear': 'σ：{value}',
  'bind_resistance': 'Iτ：{value}',
  'bind_flow': 'Jμ：{value}',
  'bind_shear_observed': 'σ：観測 {scs}/100',
  'bind_resistance_observed': 'Iτ：観測 {scs}/100',
  'bind_flow_observed': 'Jμ：観測 {scs}/100',
  'construct_vortex_name': '渦',
  'construct_shear_name': '剪断',
  'construct_resistance_name': '抵抗',
  'construct_flow_name': '流れ',
  'construct_continuum_name': '連続体',
  'construct_vortex_hint': '任意の ω 質問またはシナリオ…',
  'construct_shear_hint': 'バイアス — 二極化された枠組み…',
  'construct_resistance_hint': '対立バイアス — 制度的惰性…',
  'construct_flow_hint': 'ニュアンス — 信頼の輸送…',
  'label_baseline_delta_fmt': 'ベースライン → 精緻化：{from} → {to}（Δ {delta}）',
  'label_levers_count': '{n} {label}',
  'grok_title': 'Grok',
  'grok_subtitle': '@grok · Chronoflux 観測応答',
  'grok_copied': '@grok 応答をコピーしました',
  'report_copied': 'レポートをコピーしました',
};
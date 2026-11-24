// Habitudes — module de démonstration de l'API Vigie v1.
//
// L'état du module est `this` : init() le crée, puis view(), update(), tick()… le lisent
// et le modifient. Vigie redessine après chaque changement ; le script n'est jamais
// appelé à chaque image.

const MAX_HABITUDES = 12;
const HISTORIQUE = 400;   // jours gardés par habitude

// ── Cycle de vie ─────────────────────────────────────────────────────────────

fn init() {
    let donnees = vigie::load("donnees") ?? #{
        habitudes: [
            #{ id: 1, nom: "Boire 1,5 L d'eau", icone: "drop", jours: [] },
            #{ id: 2, nom: "Marcher 30 minutes", icone: "person-simple-walk", jours: [] },
            #{ id: 3, nom: "Lire 20 pages", icone: "book-open", jours: [] },
            #{ id: 4, nom: "Méditer", icone: "flower-lotus", jours: [] },
        ],
        prochain_id: 5,
    };
    #{
        habitudes: donnees.habitudes,
        prochain_id: donnees.prochain_id,
        vue: donnees.vue ?? "jour",
        rappel: donnees.rappel ?? "",
        jour: vigie::today(),
        edition: false,
    }
}

fn update(ev) {
    switch ev.id {
        "cocher" => { this.basculer(ev.value); }
        "supprimer" => { this.supprimer(ev.value); }
        "ajouter" => { this.ajouter(ev.fields.nouvelle ?? ""); }
        "editer" => { this.edition = !this.edition; }
        "vue" => { this.vue = ev.value; this.sauver(); }
        "copier" => { vigie::copy(bilan(this)); }
    }
}

fn tick() {
    let maintenant = vigie::now();
    if maintenant.date != this.jour {
        this.jour = maintenant.date;
        this.edition = false;
    }
    // Rappel du soir : une fois par jour, à partir de 20 h, s'il reste à faire.
    let reste = this.habitudes.len() - faites(this);
    if maintenant.hour >= 20 && reste > 0 && this.rappel != this.jour {
        this.rappel = this.jour;
        this.sauver();
        let texte = if reste == 1 { "Encore 1 habitude aujourd'hui" } else { `Encore ${reste} habitudes aujourd'hui` };
        vigie::notify(texte, "info");
    }
}

// ── Interface ────────────────────────────────────────────────────────────────

fn view() {
    let s = this;
    let total = s.habitudes.len();
    let fait = faites(s);
    let complet = total > 0 && fait == total;
    let fraction = if total == 0 { 0.0 } else { fait.to_float() / total.to_float() };

    let bilan = ui::card([
        ui::row([
            ui::column([
                ui::text(`${fait} sur ${total}`, "value", if complet { "good" } else { "neutral" }),
                ui::text(message(fait, total), "small"),
            ]),
            ui::spacer(),
            ui::segments([#{ value: "jour", label: "Aujourd'hui" }, #{ value: "semaine", label: "7 jours" }], s.vue, "vue"),
        ]),
        ui::gauge(fraction, if complet { "good" } else { "info" }),
    ]);

    if s.vue == "semaine" {
        return [bilan, ui::section("Les 7 derniers jours"), semaine(s)];
    }
    let titre = if s.edition { "Touche une habitude pour la retirer" } else { "Aujourd'hui" };
    [bilan, ui::section(titre), du_jour(s), ajout(s)]
}

fn header() {
    let e = this.edition;
    [
        ui::icon_button("copy", "Copier le bilan du jour", "copier"),
        ui::icon_button(if e { "check" } else { "pencil-simple" }, if e { "Terminer" } else { "Modifier la liste" },
            "editer", #{ tone: if e { "info" } else { "neutral" } }),
    ]
}

fn pill() {
    let total = this.habitudes.len();
    if total == 0 { return (); }
    let fait = faites(this);
    #{ icon: "list-checks", text: `${fait}/${total}`, tone: if fait == total { "good" } else { "neutral" } }
}

fn du_jour(s) {
    if s.habitudes.is_empty() {
        return ui::empty("plant", "Ajoute ta première habitude");
    }
    let lignes = [];
    for h in s.habitudes {
        let coche = s.jour in h.jours;
        let n = serie(h, s.jour);
        let detail = if n == 0 { "Pas encore de série" } else if n == 1 { "1 jour d'affilée" } else { `${n} jours d'affilée` };
        if s.edition {
            lignes.push(ui::item(#{
                icon: h.icone, title: h.nom, detail: detail,
                trailing_icon: "trash", tone: "bad", action: "supprimer", value: h.id,
            }));
        } else {
            lignes.push(ui::item(#{
                icon: h.icone, icon_tone: if coche { "good" } else { "neutral" },
                title: h.nom, detail: detail,
                trailing_icon: if coche { "check-circle" } else { "circle" },
                tone: if coche { "good" } else { "neutral" },
                action: "cocher", value: h.id,
            }));
        }
    }
    ui::list(lignes)
}

fn ajout(s) {
    if s.habitudes.len() >= MAX_HABITUDES {
        return ui::text(`${MAX_HABITUDES} habitudes au plus`, "small");
    }
    ui::card([
        ui::row([
            ui::field("nouvelle", "Nouvelle habitude", #{ submit: "ajouter" }),
            ui::button("Ajouter", "ajouter", #{ style: "primary" }),
        ]),
    ])
}

fn semaine(s) {
    if s.habitudes.is_empty() {
        return ui::empty("calendar-blank", "Rien à afficher pour l'instant");
    }
    let jours = [];
    for i in 0..7 { jours.push(vigie::date_add(s.jour, i - 6)); }

    let lignes = [];
    for h in s.habitudes {
        if !lignes.is_empty() { lignes.push(ui::divider()); }
        let points = [];
        let n = 0;
        for d in jours {
            let ok = d in h.jours;
            if ok { n += 1; }
            points.push(ui::dot(if ok { "good" } else { "neutral" }));
        }
        let ton = if n >= 5 { "good" } else if n >= 3 { "warn" } else { "neutral" };
        lignes.push(ui::row([ui::icon(h.icone), ui::text(h.nom, "strong"), ui::spacer()] + points + [ui::tag(`${n}/7`, ton)]));
    }
    ui::card(lignes)
}

// ── Actions (appelées comme méthodes : `this` est l'état) ────────────────────

fn basculer(id) {
    let i = this.habitudes.index_of(|h| h.id == id);
    if i < 0 { return; }
    let jour = this.jour;
    if jour in this.habitudes[i].jours {
        this.habitudes[i].jours.retain(|d| d != jour);
    } else {
        this.habitudes[i].jours.push(jour);
        if this.habitudes[i].jours.len() > HISTORIQUE { this.habitudes[i].jours.remove(0); }
    }
    this.sauver();
}

fn supprimer(id) {
    this.habitudes.retain(|h| h.id != id);
    if this.habitudes.is_empty() { this.edition = false; }
    this.sauver();
}

fn ajouter(texte) {
    let nom = texte;
    nom.trim();
    if nom.is_empty() || this.habitudes.len() >= MAX_HABITUDES { return; }
    this.habitudes.push(#{ id: this.prochain_id, nom: nom, icone: icone_pour(nom), jours: [] });
    this.prochain_id += 1;
    this.sauver();
}

fn sauver() {
    vigie::save("donnees", #{
        habitudes: this.habitudes, prochain_id: this.prochain_id, vue: this.vue, rappel: this.rappel,
    });
}

// ── Calculs ──────────────────────────────────────────────────────────────────

fn faites(s) {
    let n = 0;
    for h in s.habitudes { if s.jour in h.jours { n += 1; } }
    n
}

// Jours consécutifs jusqu'à aujourd'hui (ou hier, si aujourd'hui reste à faire).
fn serie(h, jour) {
    let d = if jour in h.jours { jour } else { vigie::date_add(jour, -1) };
    let n = 0;
    while d in h.jours && n < HISTORIQUE {
        n += 1;
        d = vigie::date_add(d, -1);
    }
    n
}

fn message(fait, total) {
    if total == 0 { return "Aucune habitude suivie"; }
    if fait == total { return "Journée complète, bravo"; }
    let reste = total - fait;
    if reste == 1 { "Plus qu'une à faire" } else { `Encore ${reste} à faire` }
}

fn bilan(s) {
    let date = `${s.jour.sub_string(8, 2)}/${s.jour.sub_string(5, 2)}`;
    let texte = `Habitudes du ${date} : ${faites(s)} sur ${s.habitudes.len()}`;
    for h in s.habitudes {
        let marque = if s.jour in h.jours { "✓" } else { "·" };
        texte += `\n${marque} ${h.nom}`;
    }
    texte
}

fn icone_pour(nom) {
    let n = nom.to_lower();
    if n.contains("eau") || n.contains("boire") { return "drop"; }
    if n.contains("lire") || n.contains("livre") { return "book-open"; }
    if n.contains("march") || n.contains("courir") || n.contains("course") { return "person-simple-walk"; }
    if n.contains("sport") || n.contains("muscu") { return "barbell"; }
    if n.contains("médit") || n.contains("respir") { return "flower-lotus"; }
    if n.contains("dormir") || n.contains("coucher") { return "moon"; }
    "sparkle"
}

// Jours J — comptes à rebours. Exemple sans aucune permission.

const MAX_DATES = 20;

fn init() {
    let donnees = vigie::load("donnees") ?? #{
        dates: [#{ id: 1, nom: "Nouvel an", date: prochain(vigie::today(), "01-01") }],
        prochain_id: 2,
    };
    #{ dates: donnees.dates, prochain_id: donnees.prochain_id, jour: vigie::today(), edition: false, erreur: "" }
}

fn update(ev) {
    switch ev.id {
        "ajouter" => { this.ajouter(ev.fields.nom ?? "", ev.fields.date ?? ""); }
        "supprimer" => {
            let id = ev.value;
            this.dates.retain(|d| d.id != id);
            if this.dates.is_empty() { this.edition = false; }
            this.sauver();
        }
        "editer" => { this.edition = !this.edition; }
    }
}

fn tick() {
    this.jour = vigie::today();
}

fn view() {
    let s = this;
    let lignes = [];
    for d in a_venir(s) {
        let n = vigie::days_between(s.jour, d.date);
        if s.edition {
            lignes.push(ui::item(#{ icon: "calendar-star", title: d.nom, detail: date_lisible(d.date),
                trailing_icon: "trash", tone: "bad", action: "supprimer", value: d.id }));
        } else {
            lignes.push(ui::item(#{ icon: "calendar-star", icon_tone: ton(n), title: d.nom,
                detail: date_lisible(d.date), trailing: compte(n), tone: ton(n) }));
        }
    }
    let liste = if lignes.is_empty() { ui::empty("calendar-blank", "Aucune date à venir") } else { ui::list(lignes) };

    let ajout = [
        ui::field("nom", "Événement (ex. Vacances)", #{ submit: "ajouter" }),
        ui::row([
            ui::field("date", "Date : JJ/MM/AAAA", #{ submit: "ajouter" }),
            ui::button("Ajouter", "ajouter", #{ style: "primary" }),
        ]),
    ];
    if s.erreur != "" { ajout.push(ui::text(s.erreur, "small", "bad")); }

    [liste, ui::section("Nouvelle date"), ui::card(ajout)]
}

fn header() {
    let e = this.edition;
    [ui::icon_button(if e { "check" } else { "pencil-simple" }, if e { "Terminer" } else { "Modifier" }, "editer")]
}

fn pill() {
    let suivantes = a_venir(this);
    if suivantes.is_empty() { return (); }
    let d = suivantes[0];
    let n = vigie::days_between(this.jour, d.date);
    if n > 30 { return (); }   // l'îlot ne parle que de ce qui approche
    #{ icon: "calendar-star", text: `${d.nom} · ${compte(n)}`, tone: ton(n) }
}

// ── Actions ──────────────────────────────────────────────────────────────────

fn ajouter(nom, saisie) {
    nom.trim();
    let date = depuis_saisie(saisie);
    if nom.is_empty() { this.erreur = "Donne un nom à l'événement"; return; }
    if date == () { this.erreur = "Date attendue au format JJ/MM/AAAA"; return; }
    if vigie::days_between(this.jour, date) < 0 { this.erreur = "Cette date est déjà passée"; return; }
    if this.dates.len() >= MAX_DATES { this.erreur = `${MAX_DATES} dates au plus`; return; }
    this.erreur = "";
    this.dates.push(#{ id: this.prochain_id, nom: nom, date: date });
    this.prochain_id += 1;
    this.sauver();
}

fn sauver() {
    vigie::save("donnees", #{ dates: this.dates, prochain_id: this.prochain_id });
}

// ── Calculs ──────────────────────────────────────────────────────────────────

// Dates d'aujourd'hui ou plus tard, de la plus proche à la plus lointaine.
fn a_venir(s) {
    let jour = s.jour;
    let liste = s.dates.filter(|d| vigie::days_between(jour, d.date) >= 0);
    liste.sort(|a, b| vigie::days_between(b.date, a.date));
    liste
}

fn compte(n) {
    if n == 0 { "aujourd'hui" } else if n == 1 { "demain" } else { `J-${n}` }
}

fn ton(n) {
    if n <= 1 { "good" } else if n <= 7 { "warn" } else { "neutral" }
}

// "24/12/2026" → "2026-12-24", ou () si la saisie n'est pas une date.
fn depuis_saisie(texte) {
    let morceaux = texte.split("/");
    if morceaux.len() != 3 { return (); }
    let j = morceaux[0]; j.trim();
    let m = morceaux[1]; m.trim();
    let a = morceaux[2]; a.trim();
    if j.len() == 1 { j = "0" + j; }
    if m.len() == 1 { m = "0" + m; }
    let date = `${a}-${m}-${j}`;
    let valide = true;
    try { vigie::weekday(date); } catch { valide = false; }
    if valide { date } else { () }
}

fn date_lisible(date) {
    `${date.sub_string(8, 2)}/${date.sub_string(5, 2)}/${date.sub_string(0, 4)}`
}

// Prochaine occurrence de "MM-JJ" à partir d'aujourd'hui.
fn prochain(jour, mois_jour) {
    let cette_annee = `${jour.sub_string(0, 4)}-${mois_jour}`;
    if vigie::days_between(jour, cette_annee) >= 0 { return cette_annee; }
    let annee = parse_int(jour.sub_string(0, 4)) + 1;
    `${annee}-${mois_jour}`
}

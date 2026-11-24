// Devises — exemple de module réseau : vigie::http_get ne bloque pas, la réponse
// revient plus tard dans update() sous l'action choisie ("taux").

const DEVISES = ["EUR", "USD", "GBP", "CHF", "JPY", "CAD", "CNY"];
const BASES = ["EUR", "USD", "GBP", "CHF"];
const NOMS = #{
    EUR: "Euro", USD: "Dollar américain", GBP: "Livre sterling", CHF: "Franc suisse",
    JPY: "Yen japonais", CAD: "Dollar canadien", CNY: "Yuan chinois",
};
const ICONES = #{
    EUR: "currency-eur", USD: "currency-dollar", GBP: "currency-gbp", CHF: "currency-circle-dollar",
    JPY: "currency-jpy", CAD: "currency-dollar", CNY: "currency-cny",
};

fn init() {
    let base = vigie::load("base") ?? "EUR";
    demander(base);
    #{ base: base, montant: vigie::load("montant") ?? 100.0, taux: #{}, date: "", statut: "chargement", erreur: "" }
}

fn update(ev) {
    switch ev.id {
        "taux" => {
            let reponse = ev.value;
            if reponse.ok && reponse.json != () && reponse.json.base == this.base {
                this.taux = reponse.json.rates;
                this.date = reponse.json.date;
                this.statut = "ok";
            } else if !reponse.ok {
                this.statut = "erreur";
                this.erreur = reponse.error ?? `réponse ${reponse.status} du serveur`;
            }
        }
        "base" => {
            this.base = ev.value;
            vigie::save("base", this.base);
            this.actualiser();
        }
        "montant" => {
            let saisie = ev.fields.montant ?? "";
            saisie.replace(",", ".");
            saisie.replace(" ", "");
            try {
                this.montant = parse_float(saisie);
                vigie::save("montant", this.montant);
            } catch { }
        }
        "actualiser" => { this.actualiser(); }
    }
}

fn tick() {
    this.actualiser();
}

fn view() {
    let s = this;
    let etat = switch s.statut {
        "ok" => `Taux de la BCE du ${date_lisible(s.date)}`,
        "erreur" => `Taux indisponibles : ${s.erreur}`,
        _ => "Lecture des taux…",
    };
    let entete = ui::card([
        ui::row([
            ui::column([
                ui::text(`${montant(s.montant)} ${s.base}`, "value"),
                ui::text(etat, "small", if s.statut == "erreur" { "bad" } else { "neutral" }),
            ]),
            ui::spacer(),
            ui::segments(BASES, s.base, "base"),
        ]),
        ui::row([
            ui::field("montant", "Montant à convertir", #{ submit: "montant", keep: true }),
            ui::button("Convertir", "montant", #{ style: "primary" }),
        ]),
    ]);

    let lignes = [];
    for code in DEVISES {
        if code == s.base { continue; }
        let taux = s.taux[code];
        let valeur = if taux == () { "—" } else { `${montant(s.montant * taux)} ${code}` };
        let detail = if taux == () { NOMS[code] } else { `${NOMS[code]} · 1 ${s.base} = ${precis(taux)}` };
        lignes.push(ui::item(#{ icon: ICONES[code], title: code, detail: detail, trailing: valeur }));
    }
    [entete, ui::section("Conversions"), ui::list(lignes)]
}

fn header() {
    [ui::icon_button("arrows-clockwise", "Relire les taux", "actualiser")]
}

// ── Réseau ───────────────────────────────────────────────────────────────────

fn actualiser() {
    this.statut = "chargement";
    demander(this.base);
}

fn demander(base) {
    let cibles = "";
    for code in DEVISES {
        if code == base { continue; }
        if cibles != "" { cibles += ","; }
        cibles += code;
    }
    vigie::http_get(`https://api.frankfurter.dev/v1/latest?base=${base}&symbols=${cibles}`, "taux");
}

// ── Mise en forme ────────────────────────────────────────────────────────────

// 1234.5 → "1 234,50"
fn montant(x) {
    let centimes = (x.abs() * 100.0).round().to_int();
    let decimales = centimes % 100;
    let zero = if decimales < 10 { "0" } else { "" };
    let signe = if x < 0.0 { "-" } else { "" };
    `${signe}${milliers(centimes / 100)},${zero}${decimales}`
}

// Taux avec 4 décimales : 1.0939 → "1,0939"
fn precis(x) {
    let n = (x * 10000.0).round().to_int();
    let reste = `${n % 10000}`;
    while reste.len() < 4 { reste = "0" + reste; }
    `${milliers(n / 10000)},${reste}`
}

fn milliers(n) {
    let chiffres = `${n}`;
    let sortie = "";
    let longueur = chiffres.len();
    for i in 0..longueur {
        if i > 0 && (longueur - i) % 3 == 0 { sortie += " "; }
        sortie += chiffres[i];
    }
    sortie
}

fn date_lisible(date) {
    if date.len() < 10 { return date; }
    `${date.sub_string(8, 2)}/${date.sub_string(5, 2)}/${date.sub_string(0, 4)}`
}

use std::collections::HashMap;
use std::io::{self, Write};
use std::process::Command;
use std::time::Duration;

use ratatui::crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use ratatui::layout::{Constraint, Layout, Margin};
use ratatui::style::{Color, Style, Stylize};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, List, ListItem, ListState, Padding, Paragraph, Wrap};
use ratatui::{DefaultTerminal, Frame};

#[derive(Clone)]
struct Pkg {
    repo: String,
    name: String,
    version: String,
    installed: bool,
}

#[derive(PartialEq)]
enum Tab {
    Installed,
    Search,
}

struct App {
    tab: Tab,
    installed: Vec<Pkg>,
    results: Vec<Pkg>,
    state: ListState,
    query: String,
    typing: bool,
    details: String,
    cache: HashMap<String, String>,
    stale: bool,
    status: String,
    aur: bool,
}

fn output(cmd: &str, args: &[&str]) -> String {
    Command::new(cmd)
        .args(args)
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default()
}

fn has_paru() -> bool {
    Command::new("sh")
        .args(["-c", "command -v paru"])
        .output()
        .is_ok_and(|o| o.status.success())
}

fn list_installed() -> Vec<Pkg> {
    output("pacman", &["-Qe"])
        .lines()
        .filter_map(|l| {
            let (name, version) = l.split_once(' ')?;
            Some(Pkg {
                repo: "installed".into(),
                name: name.into(),
                version: version.into(),
                installed: true,
            })
        })
        .collect()
}

// Parses `pacman -Ss` / `paru -Ss --aur` output: "repo/name version [...]" + indented description.
fn parse_search(out: &str) -> Vec<Pkg> {
    out.lines()
        .filter(|l| !l.starts_with(' '))
        .filter_map(|l| {
            let mut it = l.split_whitespace();
            let (repo, name) = it.next()?.split_once('/')?;
            Some(Pkg {
                repo: repo.into(),
                name: name.into(),
                version: it.next().unwrap_or("").into(),
                installed: l.contains("[installed") || l.contains("[Installed"),
            })
        })
        .collect()
}

fn key(p: &Pkg) -> String {
    format!("{}/{}", p.repo, p.name)
}

// Exact name, then prefix, then name contains, then description-only matches.
fn rank(name: &str, q: &str) -> u8 {
    if name == q {
        0
    } else if name.starts_with(q) {
        1
    } else if name.contains(q) {
        2
    } else {
        3
    }
}

impl App {
    fn new() -> Self {
        let mut app = App {
            tab: Tab::Installed,
            installed: list_installed(),
            results: Vec::new(),
            state: ListState::default(),
            query: String::new(),
            typing: false,
            details: String::new(),
            cache: HashMap::new(),
            stale: false,
            status: String::new(),
            aur: has_paru(),
        };
        app.state.select_first();
        app.fetch_details();
        app
    }

    fn items(&self) -> &[Pkg] {
        match self.tab {
            Tab::Installed => &self.installed,
            Tab::Search => &self.results,
        }
    }

    fn selected(&self) -> Option<Pkg> {
        self.state.selected().and_then(|i| self.items().get(i).cloned())
    }

    // Marks details as stale; they are fetched once the cursor rests (see run loop).
    fn load_details(&mut self) {
        self.stale = true;
        self.details = self
            .selected()
            .and_then(|p| self.cache.get(&key(&p)).cloned())
            .unwrap_or_default();
    }

    fn fetch_details(&mut self) {
        self.stale = false;
        let Some(p) = self.selected() else { return };
        let k = key(&p);
        if !self.cache.contains_key(&k) {
            let text = if p.installed {
                output("pacman", &["-Qi", &p.name])
            } else if p.repo == "aur" {
                output("paru", &["-Si", "--aur", &p.name])
            } else {
                output("pacman", &["-Si", &k])
            };
            self.cache.insert(k.clone(), text);
        }
        self.details = self.cache[&k].clone();
    }

    fn search(&mut self) {
        let terms: Vec<&str> = self.query.split_whitespace().collect();
        if terms.is_empty() {
            return;
        }
        let mut res = parse_search(&output("pacman", &[&["-Ss"], &terms[..]].concat()));
        if self.aur {
            res.extend(parse_search(&output("paru", &[&["-Ss", "--aur"], &terms[..]].concat())));
        }
        let q = terms.join("-").to_lowercase();
        res.sort_by_cached_key(|p| (rank(&p.name.to_lowercase(), &q), p.repo == "aur"));
        self.status = format!("{} results", res.len());
        self.results = res;
        self.state.select_first();
        self.load_details();
    }

    fn switch(&mut self, tab: Tab) {
        self.tab = tab;
        self.state.select_first();
        self.load_details();
    }

    fn refresh(&mut self) {
        self.cache.clear();
        self.installed = list_installed();
        if self.tab == Tab::Search && !self.query.is_empty() {
            self.search();
        }
        // Keep the cursor inside the list after a removal
        let len = self.items().len();
        if self.state.selected().is_some_and(|i| i >= len) {
            self.state.select(len.checked_sub(1));
        }
        self.load_details();
    }
}

// Leaves the TUI, runs a command in the plain terminal so sudo/pacman can talk to the user.
fn run_in_terminal(terminal: &mut DefaultTerminal, cmd: &str, args: &[&str]) -> io::Result<()> {
    ratatui::restore();
    let ok = Command::new(cmd).args(args).status().is_ok_and(|s| s.success());
    print!("\n{} — press Enter to return", if ok { "Done" } else { "Failed" });
    io::stdout().flush()?;
    io::stdin().read_line(&mut String::new())?;
    *terminal = ratatui::init();
    Ok(())
}

const ENABLE_AUR: &str = "sudo pacman -S --needed base-devel git && d=$(mktemp -d) && \
    git clone https://aur.archlinux.org/paru-bin.git \"$d\" && cd \"$d\" && makepkg -si";

fn main() -> io::Result<()> {
    let mut terminal = ratatui::init();
    let res = run(&mut terminal);
    ratatui::restore();
    res
}

fn run(terminal: &mut DefaultTerminal) -> io::Result<()> {
    let mut app = App::new();
    loop {
        terminal.draw(|f| draw(f, &mut app))?;
        if app.stale && !event::poll(Duration::from_millis(250))? {
            app.fetch_details();
            continue;
        }
        let Event::Key(key) = event::read()? else { continue };
        if key.kind != KeyEventKind::Press {
            continue;
        }
        if key.code == KeyCode::Char('c') && key.modifiers.contains(KeyModifiers::CONTROL) {
            return Ok(());
        }
        if app.typing {
            match key.code {
                KeyCode::Enter => {
                    app.typing = false;
                    app.search();
                }
                KeyCode::Esc => app.typing = false,
                KeyCode::Backspace => {
                    app.query.pop();
                }
                KeyCode::Char(c) => app.query.push(c),
                _ => {}
            }
            continue;
        }
        match key.code {
            KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
            KeyCode::Char('1') => app.switch(Tab::Installed),
            KeyCode::Char('2') => app.switch(Tab::Search),
            KeyCode::Tab => app.switch(if app.tab == Tab::Installed { Tab::Search } else { Tab::Installed }),
            KeyCode::Char('/') => {
                app.switch(Tab::Search);
                app.typing = true;
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if app.state.selected().is_some_and(|i| i + 1 < app.items().len()) {
                    app.state.select_next();
                }
                app.load_details();
            }
            KeyCode::Up | KeyCode::Char('k') => {
                app.state.select_previous();
                app.load_details();
            }
            KeyCode::Char('i') => {
                if let Some(p) = app.selected().filter(|p| !p.installed) {
                    if p.repo == "aur" {
                        run_in_terminal(terminal, "paru", &["-S", &p.name])?;
                    } else {
                        run_in_terminal(terminal, "sudo", &["pacman", "-S", &p.name])?;
                    }
                    app.refresh();
                }
            }
            KeyCode::Char('r') => {
                if let Some(p) = app.selected().filter(|p| p.installed) {
                    run_in_terminal(terminal, "sudo", &["pacman", "-Rns", &p.name])?;
                    app.refresh();
                }
            }
            KeyCode::Char('u') => {
                run_in_terminal(terminal, "sudo", &["pacman", "-Syu"])?;
                app.refresh();
            }
            KeyCode::Char('p') if app.aur => {
                run_in_terminal(terminal, "paru", &["-Syu"])?;
                app.refresh();
            }
            KeyCode::Char('a') if !app.aur => {
                run_in_terminal(terminal, "sh", &["-c", ENABLE_AUR])?;
                app.aur = has_paru();
                app.status = if app.aur { "AUR enabled".into() } else { "AUR not enabled".into() };
            }
            _ => {}
        }
    }
}

const ACCENT: Color = Color::Cyan;

const BANNER: [&str; 6] = [
    "██╗   ██╗██╗   ██╗███╗   ██╗ █████╗  ██████╗ ██╗",
    "╚██╗ ██╔╝██║   ██║████╗  ██║██╔══██╗██╔════╝ ██║",
    " ╚████╔╝ ██║   ██║██╔██╗ ██║███████║██║  ███╗██║",
    "  ╚██╔╝  ██║   ██║██║╚██╗██║██╔══██║██║   ██║██║",
    "   ██║   ╚██████╔╝██║ ╚████║██║  ██║╚██████╔╝██║",
    "   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚═╝",
];

// Yunagi neon gradient (BRAND.md): green -> cyan -> magenta
const NEON: [(u8, u8, u8); 3] = [(0x4a, 0xde, 0x80), (0x22, 0xd3, 0xee), (0xe8, 0x79, 0xf9)];

fn neon(t: f32) -> Color {
    let t = t.clamp(0.0, 1.0) * (NEON.len() - 1) as f32;
    let i = (t as usize).min(NEON.len() - 2);
    let (a, b, f) = (NEON[i], NEON[i + 1], t - i as f32);
    let m = |x: u8, y: u8| (x as f32 + (y as f32 - x as f32) * f) as u8;
    Color::Rgb(m(a.0, b.0), m(a.1, b.1), m(a.2, b.2))
}

fn neon_line(text: &str) -> Line<'_> {
    let n = text.chars().count().max(2) - 1;
    text.chars()
        .enumerate()
        .map(|(i, c)| Span::from(c.to_string()).fg(neon(i as f32 / n as f32)))
        .collect()
}

fn panel(title: &str) -> Block<'_> {
    Block::bordered()
        .border_type(BorderType::Rounded)
        .border_style(Style::new().dark_gray())
        .title(Span::from(format!(" {title} ")).bold())
        .padding(Padding::horizontal(1))
}

fn repo_color(repo: &str) -> Color {
    match repo {
        "aur" => Color::Magenta,
        "installed" => Color::Green,
        _ => Color::Blue,
    }
}

fn draw(f: &mut Frame, app: &mut App) {
    let area = f.area().inner(Margin::new(1, 0));
    // Big banner when there is room
    let big = area.height >= 28;
    let [banner, header, search, body, footer] = Layout::vertical([
        Constraint::Length(if big { 8 } else { 0 }),
        Constraint::Length(2),
        Constraint::Length(if app.tab == Tab::Search { 3 } else { 0 }),
        Constraint::Fill(1),
        Constraint::Length(1),
    ])
    .areas(area);

    if big {
        let lines: Vec<Line> = BANNER.iter().map(|l| neon_line(l)).collect();
        f.render_widget(
            Paragraph::new(lines).centered().block(Block::new().padding(Padding::top(1))),
            banner,
        );
    }

    // Header: tabs, AUR state
    let tab = |name: &str, on: bool| {
        if on {
            Span::from(format!(" {name} ")).bold().fg(Color::Black).bg(ACCENT)
        } else {
            Span::from(format!(" {name} ")).dark_gray()
        }
    };
    let aur = if app.aur {
        Span::from("AUR on").magenta()
    } else {
        Span::from("AUR off").dark_gray()
    };
    let [left, right] =
        Layout::horizontal([Constraint::Fill(1), Constraint::Length(8)]).areas(header);
    f.render_widget(
        Line::from(vec![
            Span::from(if big { "" } else { "YUNAGI  " }).bold().fg(ACCENT),
            tab("Installed", app.tab == Tab::Installed),
            Span::from(" "),
            tab("Search", app.tab == Tab::Search),
        ]),
        left,
    );
    f.render_widget(Line::from(aur).right_aligned(), right);

    // Search field
    if app.tab == Tab::Search {
        let cursor = if app.typing { "▏" } else { "" };
        let text = if app.query.is_empty() && !app.typing {
            Line::from("press / to search").dark_gray()
        } else {
            Line::from(format!("{}{cursor}", app.query))
        };
        let border = if app.typing { ACCENT } else { Color::DarkGray };
        f.render_widget(
            Paragraph::new(text).block(panel("Search").border_style(Style::new().fg(border))),
            search,
        );
    }

    // Package list
    let [list, details] =
        Layout::horizontal([Constraint::Percentage(45), Constraint::Fill(1)]).areas(body);
    let title = match app.tab {
        Tab::Installed => format!("Installed ({})", app.installed.len()),
        Tab::Search => format!("Results ({})", app.results.len()),
    };
    let items: Vec<ListItem> = app
        .items()
        .iter()
        .map(|p| {
            let mut spans = vec![
                Span::from(if p.installed && app.tab == Tab::Search { "● " } else { "  " }).green(),
                Span::from(p.name.clone()).bold(),
                Span::from(format!(" {}", p.version)).dark_gray(),
            ];
            if app.tab == Tab::Search {
                spans.push(Span::from(format!("  {}", p.repo)).fg(repo_color(&p.repo)));
            }
            ListItem::new(Line::from(spans))
        })
        .collect();
    f.render_stateful_widget(
        List::new(items)
            .block(panel(&title))
            .highlight_style(Style::new().bg(Color::DarkGray))
            .highlight_symbol("▌"),
        list,
        &mut app.state,
    );

    // Details: "Key : Value" lines with dimmed keys
    let lines: Vec<Line> = app
        .details
        .lines()
        .filter(|l| !l.trim().is_empty())
        .map(|l| match l.split_once(" : ") {
            Some((k, v)) if !l.starts_with(' ') => Line::from(vec![
                Span::from(format!("{:<16}", k.trim_end())).dark_gray(),
                Span::from(v.trim().to_string()),
            ]),
            _ => Line::from(format!("{:<16}{}", "", l.trim())),
        })
        .collect();
    let name = app.selected().map(|p| p.name).unwrap_or_default();
    f.render_widget(
        Paragraph::new(lines).wrap(Wrap { trim: false }).block(panel(&name)),
        details,
    );

    // Footer: key hints
    let hint = |k: &str, d: &str| {
        vec![Span::from(k.to_string()).fg(ACCENT).bold(), Span::from(format!(" {d}   ")).dark_gray()]
    };
    let mut spans = Vec::new();
    for (k, d) in [("/", "search"), ("i", "install"), ("r", "remove"), ("u", "update (pacman)")] {
        spans.extend(hint(k, d));
    }
    if app.aur {
        spans.extend(hint("p", "update (paru)"));
    }
    for (k, d) in [("tab", "switch"), ("q", "quit")] {
        spans.extend(hint(k, d));
    }
    if !app.aur {
        spans.extend(hint("a", "enable AUR"));
    }
    spans.push(Span::from(app.status.clone()).dark_gray());
    f.render_widget(Line::from(spans), footer);
}

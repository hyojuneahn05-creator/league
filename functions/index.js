const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const axios = require("axios");
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const API_BASE_URL = "https://v3.football.api-sports.io";
const K_LEAGUE_1_ID = 292;
const SEASON_YEAR = 2026;
const SEASON_START = new Date("2026-02-28T00:00:00+09:00");
const CACHE_TTL_MS = 15 * 60 * 1000;
const K_LEAGUE_LIVE_TTL_MS = 20 * 1000;
const KBO_LIVE_UPDATES_TTL_MS = 20 * 1000;
const KBO_MATCHES_UPDATES_INTV_SEC = 9000;
const DSG_CLIENTS_BASE_URL = "https://dsg-api.com/clients";
const KBO_COMPETITION_ID = 1088;
const KBO_SEASON_ID = 78635;

let leagueCache = null;
let kboLeagueCache = null;
let kboLiveUpdatesCache = null;
const teamStatsCache = new Map();
const fixtureDetailsCache = new Map();
const kboMatchDetailsCache = new Map();
const kboSquadCache = new Map();
let kboPlayerDirectoryCache = null;

const KBO_TEAM_NAMES = {
  "Doosan Bears": "두산",
  "Hanwha Eagles": "한화",
  "KIA Tigers": "KIA",
  "Kiwoom Heroes": "키움",
  "KT Wiz": "KT",
  "kt wiz Suwon": "KT",
  "LG Twins": "LG",
  "Lotte Giants": "롯데",
  "NC Dinos": "NC",
  "Samsung Lions": "삼성",
  "SSG Landers": "SSG",
};

const KBO_POSITION_LABELS = {
  "PITCHER": "P",
  "STARTING PITCHER": "P",
  "RELIEF PITCHER": "P",
  "CATCHER": "C",
  "FIRST BASEMAN": "1B",
  "SECOND BASEMAN": "2B",
  "THIRD BASEMAN": "3B",
  "SHORTSTOP": "SS",
  "LEFT FIELDER": "LF",
  "CENTER FIELDER": "CF",
  "RIGHT FIELDER": "RF",
  "OUTFIELDER": "OF",
  "INFIELDER": "IF",
  "DESIGNATED HITTER": "DH",
};

/**
 * Reads the API-Sports key from Firebase Secret Manager.
 * @return {string} configured API key
 */
function getApiKey() {
  const key = (process.env.API_SPORTS_KEY || "").trim();
  if (!key) {
    throw new Error("API_SPORTS_KEY secret is not configured");
  }
  return key;
}

/**
 * Calls API-Sports football v3.
 * @param {string} path endpoint path
 * @param {Object} params query parameters
 * @return {Promise<Object>} API response body
 */
async function apiSportsGet(path, params = {}) {
  const response = await axios.get(`${API_BASE_URL}${path}`, {
    params,
    headers: {
      "x-apisports-key": getApiKey(),
    },
  });
  return response.data;
}

/**
 * Calls API-Sports while allowing optional fixture detail sections to fail.
 * @param {string} path endpoint path
 * @param {Object} params query parameters
 * @return {Promise<Object>} API response body or an empty fallback
 */
async function apiSportsGetOptional(path, params = {}) {
  try {
    return await apiSportsGet(path, params);
  } catch (error) {
    console.error((error.response && error.response.data) || error.message);
    return {
      response: [],
      errors: (error.response && error.response.data &&
        error.response.data.errors) || {message: error.message},
    };
  }
}

/**
 * Reads Datasportsgroup credentials from Firebase Secret Manager.
 * @return {Object} configured credentials
 */
function getDsgCredentials() {
  const client = (process.env.DSG_CLIENT || "").trim();
  const username = (process.env.DSG_USERNAME || client).trim();
  const password = (process.env.DSG_PASSWORD || "").trim();
  const authkey = (process.env.DSG_AUTHKEY || "").trim();
  if (!client || !username || !password || !authkey) {
    throw new Error("Datasportsgroup secrets are not configured");
  }
  return {client, username, password, authkey};
}

/**
 * Calls Datasportsgroup baseball v3.
 * @param {string} method endpoint method
 * @param {Object} params query parameters
 * @return {Promise<Object>} API response body
 */
async function dsgBaseballGet(method, params = {}) {
  const {client, username, password, authkey} = getDsgCredentials();
  const baseUrl = `${DSG_CLIENTS_BASE_URL}/${encodeURIComponent(client)}`;
  const response = await axios.get(`${baseUrl}/baseball/${method}`, {
    params: {
      ...params,
      client,
      authkey,
      ftype: "json",
    },
    auth: {username, password},
  });
  return response.data;
}

/**
 * Calls Datasportsgroup baseball while allowing optional detail sections to
 * fail without breaking the match detail screen.
 * @param {string} method endpoint method
 * @param {Object} params query parameters
 * @return {Promise<Object>} API response body or empty fallback
 */
async function dsgBaseballGetOptional(method, params = {}) {
  try {
    return await dsgBaseballGet(method, params);
  } catch (error) {
    console.error((error.response && error.response.data) || error.message);
    return {};
  }
}

/**
 * Normalizes text for loose team-name matching.
 * @param {*} value value to normalize
 * @return {string} normalized value
 */
function normalizeText(value) {
  return `${value == null ? "" : value}`.trim().toLowerCase()
      .replace(/\s+/g, " ");
}

/**
 * Checks whether an in-memory cache entry is still usable.
 * @param {?Object} entry cache entry
 * @return {boolean} true when fresh
 */
function isCacheFresh(entry) {
  return entry && Date.now() - entry.createdAt < CACHE_TTL_MS;
}

/**
 * Checks whether an in-memory cache entry is still usable for a custom TTL.
 * @param {?Object} entry cache entry
 * @param {number} ttlMs freshness window in ms
 * @return {boolean} true when fresh
 */
function isCacheFreshFor(entry, ttlMs) {
  return entry && Date.now() - entry.createdAt < ttlMs;
}

/**
 * Converts a nullable value into a safe array.
 * @param {*} value any API value
 * @return {Array<*>} array value
 */
function asArray(value) {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

/**
 * Converts an API value to a number, preserving missing values.
 * @param {*} value value to parse
 * @return {?number} parsed number
 */
function toNullableNumber(value) {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * Converts an API value to a safe integer.
 * @param {*} value value to parse
 * @return {number} parsed integer
 */
function toInt(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

/**
 * Returns a user-facing name for draft ordering.
 * @param {Object} data user doc data
 * @param {string} uid user id
 * @return {string} display name
 */
function draftDisplayName(data, uid) {
  const name = `${(data && data.displayName) || ""}`.trim();
  if (name) return name;
  const email = `${(data && data.email) || ""}`.trim();
  if (email.includes("@")) return email.split("@")[0];
  return `Team ${uid.slice(0, 4).toUpperCase()}`;
}

/**
 * Shuffles a list in place.
 * @param {Array<*>} values array
 * @return {Array<*>} shuffled array
 */
function shuffle(values) {
  for (let i = values.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [values[i], values[j]] = [values[j], values[i]];
  }
  return values;
}

/**
 * Builds and stores a randomized draft order when the league is full.
 * @param {FirebaseFirestore.Transaction} transaction firestore transaction
 * @param {FirebaseFirestore.DocumentReference} leagueRef league ref
 * @param {Object} data league doc data
 * @param {Array<string>} members member ids
 * @param {number} teamCount expected team count
 * @return {Promise<Array<Object>>} draft order
 */
async function ensureDraftOrderInTransaction(
    transaction,
    leagueRef,
    data,
    members,
    teamCount,
) {
  const existing = Array.isArray(data.draftOrder) ? data.draftOrder : [];
  if (existing.length === teamCount) {
    return existing;
  }
  if (members.length < teamCount) {
    return existing;
  }

  const memberProfiles = [];
  for (const uid of members) {
    const userSnap = await transaction.get(db.collection("users").doc(uid));
    memberProfiles.push({
      uid,
      displayName: draftDisplayName(userSnap.data() || {}, uid),
    });
  }

  const randomized = shuffle(memberProfiles).map((member, index) => ({
    uid: member.uid,
    displayName: member.displayName,
    slot: index + 1,
  }));

  transaction.update(leagueRef, {
    draftOrder: randomized,
    draftOrderAssignedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return randomized;
}

/**
 * Uses Korean KBO names in the app while keeping unknown names visible.
 * @param {*} value team name
 * @return {string} display name
 */
function normalizeKboTeamName(value) {
  const name = `${value == null ? "" : value}`.trim();
  return KBO_TEAM_NAMES[name] || name;
}

/**
 * Loads local KBO player names captured from the 2026 roster tutorial.
 * DSG baseball Korean language feed is not enabled for this project, so this
 * directory keeps names readable without changing the upstream API language.
 * @return {Object} name and roster lookup maps
 */
function loadKboPlayerDirectory() {
  if (kboPlayerDirectoryCache) return kboPlayerDirectoryCache;

  const names = new Map();
  const byTeamNumber = new Map();
  const byTeam = new Map();
  const candidates = [];
  const filePath = path.join(__dirname, "kbo_players_season_2026.txt");

  try {
    const file = fs.readFileSync(filePath, "utf8");
    file.split(/\r?\n/).forEach((line) => {
      const parts = line.split("|").map((part) => part.trim());
      if (parts.length < 5) return;
      const [englishName, koreanName, team, position, number] = parts;
      if (!englishName) return;

      const displayName = koreanName || englishName;
      const englishKey = normalizeText(englishName);
      const existingDisplayName = names.get(englishKey);
      const shouldKeepExistingKorean =
        existingDisplayName && existingDisplayName !== englishName &&
        !koreanName;
      if (!shouldKeepExistingKorean) {
        names.set(englishKey, displayName);
        names.set(normalizeText(displayName), displayName);
        candidates.push({
          key: englishKey,
          tokens: englishKey.split(" ").filter(Boolean).sort().join(" "),
          name: displayName,
        });
      }

      const uniformNumber = firstText(number);
      const playerRow = {
        name: displayName,
        position: normalizeKboPosition(position),
        number: uniformNumber,
        team: normalizeKboTeamName(team),
        teamId: "",
      };
      if (team) {
        const teamKey = normalizeText(team);
        if (!byTeam.has(teamKey)) byTeam.set(teamKey, []);
        byTeam.get(teamKey).push(playerRow);
      }
      if (team && uniformNumber && uniformNumber !== "0") {
        byTeamNumber.set(`${normalizeText(team)}:${uniformNumber}`, playerRow);
      }
    });
  } catch (error) {
    console.error("Unable to load KBO player directory", error.message);
  }

  kboPlayerDirectoryCache = {names, byTeamNumber, byTeam, candidates};
  return kboPlayerDirectoryCache;
}

/**
 * Converts a known English KBO player name into Korean when possible.
 * @param {*} value raw player name
 * @return {string} display name
 */
function normalizeKboPlayerName(value) {
  const name = firstText(value);
  if (!name) return "";
  const directory = loadKboPlayerDirectory();
  const key = normalizeText(name);
  const exact = directory.names.get(key);
  if (exact) return exact;

  const tokens = key.split(" ").filter(Boolean);
  const tokenSet = new Set(tokens);
  const sortedTokens = [...tokenSet].sort().join(" ");
  const fuzzy = directory.candidates.find((candidate) => {
    if (candidate.tokens === sortedTokens) return true;
    return candidate.key.split(" ").every((token) => tokenSet.has(token));
  });
  return fuzzy ? fuzzy.name : name;
}

/**
 * Normalizes baseball position labels for lineup display.
 * @param {*} value raw position value
 * @return {string} short position label
 */
function normalizeKboPosition(value) {
  const raw = firstText(value).toUpperCase();
  if (!raw) return "";
  if (raw.length <= 3) return raw;
  return KBO_POSITION_LABELS[raw] || raw;
}

/**
 * Pulls the first standings table from API-Sports response shape.
 * @param {Object} standingsData raw standings response
 * @return {Array<Object>} standings rows
 */
function extractStandings(standingsData) {
  const response = standingsData.response || [];
  const first = response[0] || {};
  const league = first.league || {};
  const standings = league.standings || [];
  return standings[0] || [];
}

/**
 * Keeps preseason tables visible without carrying stale points.
 * @param {Array<Object>} standings standings rows
 * @return {Array<Object>} normalized standings rows
 */
function normalizePreseasonStandings(standings) {
  if (new Date() >= SEASON_START) return standings;

  return standings.map((team) => ({
    ...team,
    points: 0,
    goalsDiff: 0,
    all: {
      ...team.all,
      played: 0,
      win: 0,
      draw: 0,
      lose: 0,
    },
  }));
}

/**
 * Loads the K League season, teams, standings and fixtures bundle.
 * @return {Promise<Object>} normalized K League data
 */
async function fetchKLeagueData() {
  if (isCacheFreshFor(leagueCache, K_LEAGUE_LIVE_TTL_MS)) {
    return leagueCache.data;
  }

  const [seasonsData, leagueData, teamsData, standingsData, fixturesData] =
    await Promise.all([
      apiSportsGet("/leagues/seasons"),
      apiSportsGet("/leagues", {
        id: K_LEAGUE_1_ID,
        season: SEASON_YEAR,
      }),
      apiSportsGet("/teams", {
        league: K_LEAGUE_1_ID,
        season: SEASON_YEAR,
      }),
      apiSportsGet("/standings", {
        league: K_LEAGUE_1_ID,
        season: SEASON_YEAR,
      }),
      apiSportsGet("/fixtures", {
        league: K_LEAGUE_1_ID,
        season: SEASON_YEAR,
      }),
    ]);

  const standings = normalizePreseasonStandings(
      extractStandings(standingsData),
  );

  const data = {
    season: SEASON_YEAR,
    leagueId: K_LEAGUE_1_ID,
    generatedAt: new Date().toISOString(),
    seasons: seasonsData.response || [],
    league: (leagueData.response || [])[0] || null,
    teams: teamsData.response || [],
    standings,
    fixtures: fixturesData.response || [],
  };

  leagueCache = {createdAt: Date.now(), data};
  return data;
}

/**
 * Pulls KBO season information from Datasportsgroup response shape.
 * @param {Object} data raw seasons response
 * @return {?Object} season object
 */
function extractKboSeason(data) {
  const competition = (((data || {}).datasportsgroup || {}).competition) || {};
  const season = competition.season;
  return asArray(season).find((entry) => {
    return `${entry.season_id}` === `${KBO_SEASON_ID}`;
  }) || asArray(season)[0] || null;
}

/**
 * Pulls KBO round information from Datasportsgroup response shape.
 * @param {Object} data raw rounds response
 * @return {Array<Object>} round objects
 */
function extractKboRounds(data) {
  const root = (((data || {}).datasportsgroup || {}).competition) || {};
  const season = root.season || {};
  return asArray(season.round);
}

/**
 * Pulls KBO standings rows from Datasportsgroup response shape.
 * @param {Object} data raw tables response
 * @return {Array<Object>} table rows
 */
function extractKboTable(data) {
  const root = (((data || {}).datasportsgroup || {}).tour || {});
  const tourSeason = root.tour_season || {};
  const competition = tourSeason.competition || {};
  const season = competition.season || {};
  const round = season.round || {};
  const total = round.total || {};
  return asArray(total.table);
}

/**
 * Pulls KBO match rows from Datasportsgroup response shape.
 * @param {Object} data raw matches response
 * @return {Array<Object>} match rows
 */
function extractKboMatches(data) {
  const root = (((data || {}).datasportsgroup || {}).tour || {});
  const tourSeason = root.tour_season || {};
  const competition = tourSeason.competition || {};
  const season = competition.season || {};
  const discipline = season.discipline || {};
  const gender = discipline.gender || {};
  const round = gender.round || {};
  const list = round.list || {};
  return asArray(list.match);
}

/**
 * Converts a recent form string into the active streak label.
 * Examples: "WLWWW" -> "W3", "WWLLL" -> "L3", "W2" -> "W2".
 * @param {*} form raw form value
 * @return {string} active streak
 */
function normalizeKboStreak(form) {
  const raw = `${form || ""}`.trim().toUpperCase();
  if (!raw) return "";
  if (/^[WLD]\d+$/.test(raw)) return raw;

  const outcomes = raw.match(/[WLD]/g) || [];
  if (!outcomes.length) return "";

  const latest = outcomes[outcomes.length - 1];
  let count = 0;
  for (let i = outcomes.length - 1; i >= 0; i--) {
    if (outcomes[i] !== latest) break;
    count++;
  }
  return `${latest}${count}`;
}

/**
 * Normalizes KBO standings into the Flutter app shape.
 * @param {Array<Object>} rows raw table rows
 * @return {Array<Object>} normalized standings rows
 */
function normalizeKboStandings(rows) {
  return asArray(rows).map((row) => {
    const values = row.values || {};
    const runsFor = toInt(values.runs_for);
    const runsAgainst = toInt(values.runs_against);
    return {
      rank: toInt(row.position),
      teamId: `${row.team_id || ""}`,
      team: normalizeKboTeamName(row.team_name || row.short_name),
      apiTeamName: row.team_name || row.short_name || "",
      played: toInt(values.matches_total),
      wins: toInt(values.matches_won),
      draws: toInt(values.matches_tied),
      losses: toInt(values.matches_lost),
      runsFor,
      runsAgainst,
      runsDiff: toInt(values.runs_difference || runsFor - runsAgainst),
      percentage: Number(values.percentage || 0),
      gamesBehind: `${values.games_behind || "0"}`,
      home: `${values.home || ""}`,
      road: `${values.road || ""}`,
      streak: normalizeKboStreak(row.form),
    };
  }).sort((a, b) => {
    const rank = a.rank - b.rank;
    if (rank !== 0) return rank;
    return b.percentage - a.percentage;
  });
}

/**
 * Normalizes KBO matches into the Flutter app shape.
 * @param {Array<Object>} matches raw match rows
 * @return {Array<Object>} normalized match rows
 */
function normalizeKboMatches(matches) {
  return asArray(matches).map((match) => {
    const venue = (((match.match_extra || {}).venue) || match.venue || {});
    return {
      id: toInt(match.match_id),
      date: `${match.date || ""}`,
      time: `${match.time || ""}`,
      dateUtc: `${match.date_utc || ""}`,
      timeUtc: `${match.time_utc || ""}`,
      homeTeamId: `${match.team_a_id || ""}`,
      home: normalizeKboTeamName(match.team_a_name),
      awayTeamId: `${match.team_b_id || ""}`,
      away: normalizeKboTeamName(match.team_b_name),
      status: `${match.status || ""}`,
      winner: `${match.winner || ""}`,
      homeScore: toNullableNumber(match.score_a),
      awayScore: toNullableNumber(match.score_b),
      lastUpdated: `${match.last_updated || ""}`,
      venue: `${venue.venue_name || ""}`,
      city: `${venue.venue_city || ""}`,
    };
  }).sort((a, b) => {
    const left = `${a.date} ${a.time} ${a.id}`;
    const right = `${b.date} ${b.time} ${b.id}`;
    return left.localeCompare(right);
  });
}

/**
 * Pulls recently updated KBO match rows from Datasportsgroup response shape.
 * @param {Object} data raw updates response
 * @return {Array<Object>} updated match rows
 */
function extractKboUpdatedMatches(data) {
  return collectDsgValues(data, "match")
      .filter((row) => row && typeof row === "object");
}

/**
 * Overlays a live update row onto an existing normalized KBO match.
 * @param {Object} base normalized base match
 * @param {Object} patch normalized update row
 * @return {Object} merged match
 */
function mergeKboMatchUpdate(base, patch) {
  if (!patch || !patch.id) return base;
  return {
    ...base,
    date: patch.date || base.date,
    time: patch.time || base.time,
    dateUtc: patch.dateUtc || base.dateUtc,
    timeUtc: patch.timeUtc || base.timeUtc,
    homeTeamId: patch.homeTeamId || base.homeTeamId,
    home: patch.home || base.home,
    awayTeamId: patch.awayTeamId || base.awayTeamId,
    away: patch.away || base.away,
    status: patch.status || base.status,
    winner: patch.winner || base.winner,
    homeScore: patch.homeScore ?? base.homeScore,
    awayScore: patch.awayScore ?? base.awayScore,
    lastUpdated: patch.lastUpdated || base.lastUpdated || "",
    venue: patch.venue || base.venue,
    city: patch.city || base.city,
  };
}

/**
 * Loads and caches recent KBO live match updates.
 * @return {Promise<Object>} update maps keyed by match id
 */
async function fetchKboLiveUpdates() {
  if (isCacheFresh(kboLiveUpdatesCache) &&
    Date.now() - kboLiveUpdatesCache.createdAt < KBO_LIVE_UPDATES_TTL_MS) {
    return kboLiveUpdatesCache.data;
  }

  const data = await dsgBaseballGet("get_matches_updates", {
    intv: KBO_MATCHES_UPDATES_INTV_SEC,
  });
  const rawMatches = extractKboUpdatedMatches(data);
  const normalized = normalizeKboMatches(rawMatches);
  const byId = new Map();
  normalized.forEach((match) => {
    if (match.id > 0) byId.set(`${match.id}`, match);
  });

  const output = {byId};
  kboLiveUpdatesCache = {createdAt: Date.now(), data: output};
  return output;
}

/**
 * Loads KBO live updates without failing the main schedule/detail screens.
 * @return {Promise<Object>} safe update maps
 */
async function fetchKboLiveUpdatesOptional() {
  try {
    return await fetchKboLiveUpdates();
  } catch (error) {
    console.error("Unable to load KBO live updates",
        (error.response && error.response.data) || error.message);
    return kboLiveUpdatesCache ? kboLiveUpdatesCache.data : {byId: new Map()};
  }
}

/**
 * Recursively collects objects stored under a specific API key.
 * @param {*} value root value
 * @param {string} key key to collect
 * @return {Array<*>} collected values
 */
function collectDsgValues(value, key) {
  const results = [];
  const visit = (entry) => {
    if (!entry || typeof entry !== "object") return;
    if (Array.isArray(entry)) {
      entry.forEach(visit);
      return;
    }
    Object.entries(entry).forEach(([entryKey, entryValue]) => {
      if (entryKey === key) {
        results.push(...asArray(entryValue));
      }
      visit(entryValue);
    });
  };
  visit(value);
  return results;
}

/**
 * Picks the first non-empty string value.
 * @param {...*} values candidate values
 * @return {string} first non-empty value
 */
function firstText(...values) {
  for (const value of values) {
    const text = `${value == null ? "" : value}`.trim();
    if (text && text !== "null") return text;
  }
  return "";
}

/**
 * Reads a player/person name from variable DSG node shapes.
 * @param {Object} row raw person row
 * @return {string} display name
 */
function readKboPersonName(row) {
  const localName = firstText(
      row.name_local,
      row.local_name,
      row.native_name,
      row.name_native,
      row.name_ko,
      row.korean_name,
      row.person_name_local,
      row.player_name_local,
  );
  if (localName) return localName;

  return normalizeKboPlayerName(
      firstText(
          row.name,
          row.person_name,
          row.player_name,
          row.full_name,
          row.display_name,
          [row.first_name, row.last_name].filter(Boolean).join(" "),
          [row.given_name, row.family_name].filter(Boolean).join(" "),
      ),
  );
}

/**
 * Reads a player/person id from variable DSG node shapes.
 * @param {Object} row raw person row
 * @return {string} person id
 */
function readKboPersonId(row) {
  return firstText(
      row.people_id,
      row.person_id,
      row.player_id,
      row.id,
      row.person && row.person.id,
      row.people && row.people.id,
      row.player && row.player.id,
  );
}

/**
 * Reads a uniform number from variable DSG node shapes.
 * @param {Object} row raw person row
 * @return {string} uniform number
 */
function readKboUniformNumber(row) {
  return firstText(
      row.shirt_number,
      row.jersey_number,
      row.uniform_number,
      row.number,
      row.player_number,
      row.people_number,
  );
}

/**
 * Reads a baseball position from variable DSG node shapes.
 * @param {Object} row raw person row
 * @return {string} short position
 */
function readKboPosition(row) {
  return normalizeKboPosition(
      firstText(
          row.position,
          row.position_name,
          row.position_short,
          row.field_position,
          row.role,
      ),
  );
}

/**
 * Reads a team display name from a KBO detail row.
 * @param {Object} row raw row
 * @param {Object} match raw match
 * @return {string} normalized team name
 */
function readKboDetailTeamName(row, match) {
  const teamId = firstText(row.team_id, row.competitor_id, row.club_id);
  const fallback = firstText(
      row.team_name,
      row.competitor_name,
      row.club_name,
  );
  if (`${teamId}` === `${match.team_a_id}`) {
    return normalizeKboTeamName(match.team_a_name);
  }
  if (`${teamId}` === `${match.team_b_id}`) {
    return normalizeKboTeamName(match.team_b_name);
  }
  return normalizeKboTeamName(fallback);
}

/**
 * Normalizes period rows into inning scores.
 * @param {Object} match raw match
 * @return {Array<Object>} normalized innings
 */
function normalizeKboInnings(match) {
  const periods = [
    ...collectDsgValues(match, "period"),
    ...collectDsgValues(match, "inning"),
  ];
  const rows = periods.map((period, index) => {
    const number = firstText(
        period.number,
        period.period_number,
        period.inning,
        period.sequence,
        index + 1,
    );
    return {
      label: number,
      home: firstText(
          period.score_a,
          period.home_score,
          period.runs_a,
          period.runs_home,
      ),
      away: firstText(
          period.score_b,
          period.away_score,
          period.runs_b,
          period.runs_away,
      ),
    };
  }).filter((row) => row.home || row.away);

  return rows.slice(0, 16);
}

/**
 * Determines whether a person row represents a starter.
 * @param {Object} row raw person row
 * @return {boolean} true when starter-like
 */
function isKboStarter(row) {
  const value = firstText(
      row.starter,
      row.starting,
      row.is_starter,
      row.lineup,
      row.lineup_status,
      row.type,
  ).toLowerCase();
  if (!value) return false;
  return ["1", "true", "yes", "starter", "starting", "start"].some((token) => {
    return value.includes(token);
  });
}

/**
 * Pulls squad/player rows from a DSG squad response.
 * @param {Object} data raw squad response
 * @return {Array<Object>} normalized roster rows
 */
function extractKboSquadPlayers(data) {
  const rows = [
    ...collectDsgValues(data, "people"),
    ...collectDsgValues(data, "person"),
    ...collectDsgValues(data, "player"),
  ].filter((row) => row && typeof row === "object");

  return rows.map((row) => {
    const teamName = normalizeKboTeamName(firstText(
        row.team_name,
        row.club_name,
        row.competitor_name,
    ));
    const number = readKboUniformNumber(row);
    return {
      playerId: readKboPersonId(row),
      name: readKboPersonName(row),
      number,
      position: readKboPosition(row),
      teamId: firstText(row.team_id, row.club_id, row.competitor_id),
      team: teamName,
    };
  }).filter((row) => row.name);
}

/**
 * Builds lookup maps for KBO roster enrichment.
 * @param {Array<Object>} squadResponses raw squad API responses
 * @return {Object} roster lookup maps
 */
function buildKboRosterLookup(squadResponses) {
  const directory = loadKboPlayerDirectory();
  const byId = new Map();
  const byTeamNumber = new Map(directory.byTeamNumber);
  const byName = new Map();
  const byTeam = new Map(Array.from(directory.byTeam.entries()).map(
      ([key, value]) => [key, [...value]],
  ));

  squadResponses.flatMap(extractKboSquadPlayers).forEach((player) => {
    if (player.playerId) byId.set(`${player.playerId}`, player);
    if (player.team && player.number) {
      const teamNumberKey = `${normalizeText(player.team)}:${player.number}`;
      byTeamNumber.set(teamNumberKey, player);
    }
    if (player.teamId && player.number) {
      byTeamNumber.set(`${player.teamId}:${player.number}`, player);
    }
    byName.set(normalizeText(player.name), player);
    if (player.team) {
      const teamKey = normalizeText(player.team);
      if (!byTeam.has(teamKey)) byTeam.set(teamKey, []);
      byTeam.get(teamKey).push(player);
    }
    if (player.teamId) {
      const teamIdKey = `id:${player.teamId}`;
      if (!byTeam.has(teamIdKey)) byTeam.set(teamIdKey, []);
      byTeam.get(teamIdKey).push(player);
    }
  });

  return {byId, byTeamNumber, byName, byTeam};
}

/**
 * Returns a stable sort order for baseball positions.
 * @param {string} position normalized position
 * @return {number} priority
 */
function kboPositionPriority(position) {
  return {
    "P": 0,
    "C": 1,
    "1B": 2,
    "2B": 3,
    "3B": 4,
    "SS": 5,
    "LF": 6,
    "CF": 7,
    "RF": 8,
    "OF": 9,
    "IF": 10,
    "DH": 11,
  }[position] ?? 99;
}

/**
 * Creates a projected starting lineup from the team roster.
 * Used when the detail payload does not expose the batting order.
 * @param {string} teamName normalized team name
 * @param {string} teamId DSG team id
 * @param {Object} rosterLookup KBO roster lookup maps
 * @return {Object} projected starter data
 */
function buildProjectedKboLineup(teamName, teamId, rosterLookup) {
  const rawPlayers = rosterLookup.byTeam.get(normalizeText(teamName)) ||
    rosterLookup.byTeam.get(`id:${teamId}`) ||
    [];
  const uniquePlayers = Array.from(new Map(rawPlayers.map((player) => {
    const key = `${normalizeText(player.name)}|${player.number}|${player.position}`;
    return [key, player];
  })).values()).sort((a, b) => {
    const positionOrder = kboPositionPriority(a.position) -
      kboPositionPriority(b.position);
    if (positionOrder !== 0) return positionOrder;
    const leftNumber = toInt(a.number) > 0 ? toInt(a.number) : 999;
    const rightNumber = toInt(b.number) > 0 ? toInt(b.number) : 999;
    const numberOrder = leftNumber - rightNumber;
    if (numberOrder !== 0) return numberOrder;
    return a.name.localeCompare(b.name, "ko");
  });

  const pitchers = uniquePlayers.filter((player) => player.position === "P");
  const hitters = uniquePlayers.filter((player) => player.position !== "P");
  const used = new Set();
  const projected = [];

  const takeOne = (positions) => {
    const found = hitters.find((player) => {
      if (used.has(player.name)) return false;
      return positions.includes(player.position);
    });
    if (!found) return;
    used.add(found.name);
    projected.push(found);
  };

  takeOne(["C"]);
  takeOne(["1B", "IF"]);
  takeOne(["2B", "IF"]);
  takeOne(["3B", "IF"]);
  takeOne(["SS", "IF"]);
  takeOne(["LF", "OF"]);
  takeOne(["CF", "OF"]);
  takeOne(["RF", "OF"]);
  takeOne(["DH", "OF", "IF", "C"]);

  hitters.forEach((player) => {
    if (projected.length >= 9 || used.has(player.name)) return;
    used.add(player.name);
    projected.push(player);
  });

  return {
    starterPitcher: pitchers[0] ? pitchers[0].name : "",
    players: projected.slice(0, 9).map((player, index) => ({
      order: index + 1,
      name: player.name,
      position: player.position || "",
      number: player.number || "",
    })),
  };
}

/**
 * Finds a roster row that matches a detailed lineup/person row.
 * @param {Object} row raw lineup row
 * @param {Object} lookup roster lookup maps
 * @param {string} teamName normalized team name
 * @param {string} teamId team id
 * @return {?Object} matching roster row
 */
function findKboRosterPlayer(row, lookup, teamName, teamId) {
  const playerId = readKboPersonId(row);
  if (playerId && lookup.byId.has(`${playerId}`)) {
    return lookup.byId.get(`${playerId}`);
  }

  const number = readKboUniformNumber(row);
  if (number) {
    const teamKey = `${normalizeText(teamName)}:${number}`;
    const idKey = `${teamId}:${number}`;
    if (lookup.byTeamNumber.has(teamKey)) {
      return lookup.byTeamNumber.get(teamKey);
    }
    if (teamId && lookup.byTeamNumber.has(idKey)) {
      return lookup.byTeamNumber.get(idKey);
    }
  }

  const name = readKboPersonName(row);
  return lookup.byName.get(normalizeText(name)) || null;
}

/**
 * Loads and caches one KBO team squad for player metadata enrichment.
 * @param {string} teamId DSG team id
 * @return {Promise<Object>} raw squad response
 */
async function fetchKboSquad(teamId) {
  const cacheKey = `${teamId}`;
  const cached = kboSquadCache.get(cacheKey);
  if (isCacheFresh(cached)) return cached.data;

  const data = await dsgBaseballGetOptional("get_squad", {
    team: teamId,
    detailed: "yes",
  });
  kboSquadCache.set(cacheKey, {createdAt: Date.now(), data});
  return data;
}

/**
 * Normalizes KBO lineups from the detailed match payload.
 * @param {Object} match raw match
 * @param {Object} rosterLookup KBO roster lookup maps
 * @return {Array<Object>} normalized team lineups
 */
function normalizeKboLineups(match, rosterLookup = buildKboRosterLookup([])) {
  const people = [
    ...collectDsgValues(match, "people"),
    ...collectDsgValues(match, "person"),
    ...collectDsgValues(match, "player"),
  ].filter((row) => row && typeof row === "object");

  const teams = new Map();
  const ensureTeam = (teamId, teamName) => {
    const key = firstText(teamId, teamName, "unknown");
    if (!teams.has(key)) {
      teams.set(key, {
        teamId: `${teamId || ""}`,
        team: teamName,
        starterPitcher: "",
        players: [],
      });
    }
    return teams.get(key);
  };

  people.forEach((row) => {
    const teamId = firstText(row.team_id, row.competitor_id, row.club_id);
    const teamName = readKboDetailTeamName(row, match);
    const roster = findKboRosterPlayer(row, rosterLookup, teamName, teamId);
    const name = readKboPersonName(roster || row) || readKboPersonName(row);
    if (!name) return;

    const position = readKboPosition(row) || (roster && roster.position) || "";
    const order = firstText(
        row.batting_order,
        row.bat_order,
        row.order,
        row.lineup_order,
    );
    const team = ensureTeam(teamId, teamName);

    if (
      (position === "P" || position === "SP" ||
        firstText(row.role).toLowerCase().includes("pitcher")) &&
      (isKboStarter(row) || !team.starterPitcher)
    ) {
      team.starterPitcher = name;
    }

    if (!order && !isKboStarter(row)) return;
    if (!order && position === "P") return;

    const numericOrder = Number(order);
    const duplicate = team.players.some((player) => {
      return player.name === name && `${player.order}` === `${numericOrder}`;
    });
    if (duplicate) return;

    team.players.push({
      order: Number.isFinite(numericOrder) && numericOrder > 0 ?
        numericOrder :
        team.players.length + 1,
      name,
      position: position || firstText(row.role).toUpperCase(),
      number: readKboUniformNumber(row) || (roster && roster.number) || "",
    });
  });

  const normalized = Array.from(teams.values()).map((team) => ({
    ...team,
    players: team.players
        .sort((a, b) => a.order - b.order)
        .slice(0, 12),
  })).map((team) => {
    const projected = buildProjectedKboLineup(
        team.team,
        team.teamId,
        rosterLookup,
    );
    const shouldFallbackToProjected = team.players.length < 7 &&
      projected.players.length >= team.players.length;
    return {
      ...team,
      starterPitcher: team.starterPitcher || projected.starterPitcher,
      players: shouldFallbackToProjected ? projected.players : team.players,
      source: shouldFallbackToProjected ? "projected" : "official",
    };
  });

  const teamA = normalizeKboTeamName(match.team_a_name);
  const teamB = normalizeKboTeamName(match.team_b_name);
  const ordered = [teamA, teamB].map((name) => {
    return normalized.find((lineup) => lineup.team === name) || {
      team: name,
      teamId: "",
      starterPitcher: "",
      players: [],
      source: "",
    };
  });
  return ordered;
}

/**
 * Normalizes pitcher decisions if provided by the detail response.
 * @param {Object} match raw match
 * @return {Object} normalized pitching data
 */
function normalizeKboPitching(match) {
  const firstPersonName = (...values) => {
    for (const value of values) {
      if (!value) continue;
      if (typeof value === "object") {
        const name = readKboPersonName(value);
        if (name) return name;
        continue;
      }
      const name = normalizeKboPlayerName(value);
      if (name) return name;
    }
    return "";
  };

  const fields = {
    home: {
      name: firstPersonName(
          match.winning_pitcher_a,
          match.win_pitcher_a,
          match.losing_pitcher_a,
          match.loss_pitcher_a,
      ),
      result: firstText(match.pitcher_result_a),
      saveName: firstPersonName(
          match.save_pitcher_a,
          match.saving_pitcher_a,
          match.pitcher_save_a,
          match.save_a,
      ),
    },
    away: {
      name: firstPersonName(
          match.winning_pitcher_b,
          match.win_pitcher_b,
          match.losing_pitcher_b,
          match.loss_pitcher_b,
      ),
      result: firstText(match.pitcher_result_b),
      saveName: firstPersonName(
          match.save_pitcher_b,
          match.saving_pitcher_b,
          match.pitcher_save_b,
          match.save_b,
      ),
    },
  };

  collectDsgValues(match, "event").forEach((event) => {
    const type = firstText(event.type, event.event_type).toLowerCase();
    const decision = firstText(event.decision, event.result).toLowerCase();
    if (!type.includes("pitch") && !decision) return;

    const name = readKboPersonName(event);
    if (!name) return;
    const teamName = readKboDetailTeamName(event, match);
    const target = teamName === normalizeKboTeamName(match.team_b_name) ?
      fields.away :
      fields.home;
    target.name = target.name || name;
    if (decision.includes("win") || decision.includes("승")) {
      target.result = "승";
    } else if (decision.includes("loss") || decision.includes("패")) {
      target.result = "패";
    } else if (
      decision.includes("save") ||
      decision.includes("sv") ||
      decision.includes("세") ||
      type.includes("save")
    ) {
      target.saveName = target.saveName || name;
    }
  });

  return fields;
}

/**
 * Loads detail data for one KBO match.
 * @param {string|number} matchId DSG match id
 * @return {Promise<Object>} normalized detail data
 */
async function fetchKboMatchDetails(matchId) {
  const cacheKey = `${matchId}`;
  const cached = kboMatchDetailsCache.get(cacheKey);
  if (isCacheFresh(cached)) {
    const liveUpdates = await fetchKboLiveUpdatesOptional();
    const patch = liveUpdates.byId.get(cacheKey);
    if (!patch) return cached.data;
    return {
      ...cached.data,
      generatedAt: new Date().toISOString(),
      match: mergeKboMatchUpdate(cached.data.match || {}, patch),
    };
  }

  const data = await dsgBaseballGet("get_matches", {
    type: "match",
    id: matchId,
    detailed: "yes",
  });
  const rootMatch = (((data || {}).datasportsgroup || {}).match);
  const match = extractKboMatches(data)[0] ||
    asArray(rootMatch)[0] ||
    {};
  const normalizedMatch = normalizeKboMatches([match])[0] || {};
  const squadResponses = await Promise.all([
    normalizedMatch.homeTeamId,
    normalizedMatch.awayTeamId,
  ].filter(Boolean).map(fetchKboSquad));
  const rosterLookup = buildKboRosterLookup(squadResponses);
  const detail = {
    generatedAt: new Date().toISOString(),
    match: normalizedMatch,
    innings: normalizeKboInnings(match),
    pitching: normalizeKboPitching(match),
    lineups: normalizeKboLineups(match, rosterLookup),
  };

  kboMatchDetailsCache.set(cacheKey, {createdAt: Date.now(), data: detail});
  const liveUpdates = await fetchKboLiveUpdatesOptional();
  const patch = liveUpdates.byId.get(cacheKey);
  if (!patch) return detail;
  return {
    ...detail,
    generatedAt: new Date().toISOString(),
    match: mergeKboMatchUpdate(detail.match || {}, patch),
  };
}

/**
 * Loads the KBO season, standings and schedule bundle.
 * @return {Promise<Object>} normalized KBO data
 */
async function fetchKboLeagueData() {
  if (isCacheFresh(kboLeagueCache)) {
    const liveUpdates = await fetchKboLiveUpdatesOptional();
    return {
      ...kboLeagueCache.data,
      generatedAt: new Date().toISOString(),
      matches: (kboLeagueCache.data.matches || []).map((match) => {
        const patch = liveUpdates.byId.get(`${match.id}`);
        return patch ? mergeKboMatchUpdate(match, patch) : match;
      }),
    };
  }

  const [seasonsData, roundsData, tablesData, matchesData] =
    await Promise.all([
      dsgBaseballGet("get_seasons", {comp_id: KBO_COMPETITION_ID}),
      dsgBaseballGet("get_rounds", {season_id: KBO_SEASON_ID}),
      dsgBaseballGet("get_tables", {type: "season", id: KBO_SEASON_ID}),
      dsgBaseballGet("get_matches", {type: "season", id: KBO_SEASON_ID}),
    ]);

  const data = {
    season: SEASON_YEAR,
    competitionId: KBO_COMPETITION_ID,
    seasonId: KBO_SEASON_ID,
    generatedAt: new Date().toISOString(),
    seasonInfo: extractKboSeason(seasonsData),
    rounds: extractKboRounds(roundsData),
    standings: normalizeKboStandings(extractKboTable(tablesData)),
    matches: normalizeKboMatches(extractKboMatches(matchesData)),
  };

  kboLeagueCache = {createdAt: Date.now(), data};
  const liveUpdates = await fetchKboLiveUpdatesOptional();
  return {
    ...data,
    generatedAt: new Date().toISOString(),
    matches: data.matches.map((match) => {
      const patch = liveUpdates.byId.get(`${match.id}`);
      return patch ? mergeKboMatchUpdate(match, patch) : match;
    }),
  };
}

/**
 * Finds a team by API id or display name.
 * @param {string|number} teamQuery team id or name
 * @return {Promise<?Object>} matching team object
 */
async function findTeamByQuery(teamQuery) {
  const data = await fetchKLeagueData();
  const teams = data.teams || [];
  const teamId = Number(teamQuery);

  if (Number.isInteger(teamId) && teamId > 0) {
    const foundById = teams.find((entry) => {
      return entry.team && entry.team.id === teamId;
    });
    return foundById ? foundById.team : {
      id: teamId,
      name: `${teamId}`,
    };
  }

  const target = normalizeText(teamQuery);
  const foundByName = teams.find((entry) => {
    const team = entry.team || {};
    return normalizeText(team.name) === target ||
      normalizeText(team.name).includes(target) ||
      target.includes(normalizeText(team.name));
  });
  return foundByName ? foundByName.team : null;
}

/**
 * Loads statistics for one K League team.
 * @param {string|number} teamQuery team id or name
 * @return {Promise<Object>} normalized team statistics data
 */
async function fetchTeamStatistics(teamQuery) {
  const team = await findTeamByQuery(teamQuery);
  if (!team || !team.id) {
    const error = new Error("Team was not found");
    error.statusCode = 404;
    throw error;
  }

  const cacheKey = `${SEASON_YEAR}:${team.id}`;
  const cached = teamStatsCache.get(cacheKey);
  if (isCacheFresh(cached)) {
    return cached.data;
  }

  const statsData = await apiSportsGet("/teams/statistics", {
    league: K_LEAGUE_1_ID,
    season: SEASON_YEAR,
    team: team.id,
  });

  const data = {
    season: SEASON_YEAR,
    leagueId: K_LEAGUE_1_ID,
    team,
    statistics: statsData.response || null,
  };

  teamStatsCache.set(cacheKey, {createdAt: Date.now(), data});
  return data;
}

/**
 * Loads every fixture-specific data source that API-Sports exposes.
 * @param {string|number} fixtureQuery fixture id
 * @return {Promise<Object>} normalized fixture details data
 */
async function fetchFixtureDetails(fixtureQuery) {
  const fixtureId = Number(fixtureQuery);
  if (!Number.isInteger(fixtureId) || fixtureId <= 0) {
    const error = new Error("fixture query parameter must be a valid id");
    error.statusCode = 400;
    throw error;
  }

  const cacheKey = `${fixtureId}`;
  const cached = fixtureDetailsCache.get(cacheKey);
  if (isCacheFreshFor(cached, K_LEAGUE_LIVE_TTL_MS)) {
    return cached.data;
  }

  const [
    fixtureData,
    statisticsData,
    eventsData,
    lineupsData,
    playersData,
  ] = await Promise.all([
    apiSportsGet("/fixtures", {id: fixtureId}),
    apiSportsGetOptional("/fixtures/statistics", {fixture: fixtureId}),
    apiSportsGetOptional("/fixtures/events", {fixture: fixtureId}),
    apiSportsGetOptional("/fixtures/lineups", {fixture: fixtureId}),
    apiSportsGetOptional("/fixtures/players", {fixture: fixtureId}),
  ]);

  const data = {
    season: SEASON_YEAR,
    leagueId: K_LEAGUE_1_ID,
    fixtureId,
    generatedAt: new Date().toISOString(),
    fixture: (fixtureData.response || [])[0] || null,
    statistics: statisticsData.response || [],
    events: eventsData.response || [],
    lineups: lineupsData.response || [],
    players: playersData.response || [],
    errors: {
      statistics: statisticsData.errors || [],
      events: eventsData.errors || [],
      lineups: lineupsData.errors || [],
      players: playersData.errors || [],
    },
  };

  fixtureDetailsCache.set(cacheKey, {createdAt: Date.now(), data});
  return data;
}

exports.getLeagueStandings = onRequest(
    {cors: true, secrets: ["API_SPORTS_KEY"]},
    async (req, res) => {
      try {
        res.json(await fetchKLeagueData());
      } catch (error) {
        console.error((error.response && error.response.data) || error.message);
        res.status(error.statusCode || 500).json({
          error: "Error fetching K League data",
        });
      }
    },
);

exports.getKboLeagueData = onRequest(
    {
      cors: true,
      secrets: [
        "DSG_CLIENT",
        "DSG_USERNAME",
        "DSG_PASSWORD",
        "DSG_AUTHKEY",
      ],
    },
    async (req, res) => {
      try {
        res.json(await fetchKboLeagueData());
      } catch (error) {
        console.error((error.response && error.response.data) || error.message);
        res.status(error.statusCode || 500).json({
          error: "Error fetching KBO data",
        });
      }
    },
);

exports.getKboMatchDetails = onRequest(
    {
      cors: true,
      secrets: [
        "DSG_CLIENT",
        "DSG_USERNAME",
        "DSG_PASSWORD",
        "DSG_AUTHKEY",
      ],
    },
    async (req, res) => {
      try {
        const match = req.query.match;
        if (!match) {
          res.status(400).json({
            error: "match query parameter is required",
          });
          return;
        }

        res.json(await fetchKboMatchDetails(match));
      } catch (error) {
        console.error((error.response && error.response.data) || error.message);
        res.status(error.statusCode || 500).json({
          error: "Error fetching KBO match details",
        });
      }
    },
);

exports.getTeamStatistics = onRequest(
    {cors: true, secrets: ["API_SPORTS_KEY"]},
    async (req, res) => {
      try {
        const team = req.query.team;
        if (!team) {
          res.status(400).json({error: "team query parameter is required"});
          return;
        }

        res.json(await fetchTeamStatistics(team));
      } catch (error) {
        console.error((error.response && error.response.data) || error.message);
        res.status(error.statusCode || 500).json({
          error: "Error fetching team statistics",
        });
      }
    },
);

exports.getFixtureDetails = onRequest(
    {cors: true, secrets: ["API_SPORTS_KEY"]},
    async (req, res) => {
      try {
        const fixture = req.query.fixture;
        if (!fixture) {
          res.status(400).json({
            error: "fixture query parameter is required",
          });
          return;
        }

        res.json(await fetchFixtureDetails(fixture));
      } catch (error) {
        console.error((error.response && error.response.data) || error.message);
        res.status(error.statusCode || 500).json({
          error: "Error fetching fixture details",
        });
      }
    },
);

exports.joinLeagueByInviteCode = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const code = `${(request.data && request.data.code) || ""}`
      .trim()
      .toUpperCase();
  if (!code) {
    throw new HttpsError("invalid-argument", "Invite code is required");
  }

  const query = await db.collection("leagues")
      .where("inviteCode", "==", code)
      .limit(1)
      .get();
  if (query.empty) {
    throw new HttpsError("not-found", "Invite code not found");
  }

  const leagueRef = query.docs[0].ref;
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(leagueRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "League not found");
    }

    const data = snapshot.data() || {};
    const members = Array.isArray(data.members) ? [...data.members] : [];
    const teamCount = Number(data.teamCount || 8);
    let joined = false;

    if (!members.includes(uid)) {
      if (members.length >= teamCount) {
        throw new HttpsError(
            "failed-precondition",
            "League is already full",
        );
      }

      members.push(uid);
      joined = true;
    }

    const draftOrder = await ensureDraftOrderInTransaction(
        transaction,
        leagueRef,
        data,
        members,
        teamCount,
    );

    if (joined) {
      transaction.update(leagueRef, {
        members,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        leagueIds: admin.firestore.FieldValue.arrayUnion(leagueRef.id),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    const rawDraftDate = data.draftDateTime;
    const draftDateTime =
      rawDraftDate && typeof rawDraftDate.toDate === "function" ?
        rawDraftDate.toDate().toISOString() :
        "";

    return {
      leagueId: leagueRef.id,
      leagueName: `${data.name || "My League"}`,
      sport: `${data.sport || "soccer"}`,
      draftDateTime,
      teamCount,
      memberCount: members.length,
      inviteCode: `${data.inviteCode || code}`,
      ownerId: `${data.ownerId || ""}`,
      draftOrder,
    };
  });
});

exports.ensureDraftOrder = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const leagueId = `${(request.data && request.data.leagueId) || ""}`.trim();
  if (!leagueId) {
    throw new HttpsError("invalid-argument", "leagueId is required");
  }

  const leagueRef = db.collection("leagues").doc(leagueId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(leagueRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "League not found");
    }

    const data = snapshot.data() || {};
    const members = Array.isArray(data.members) ? [...data.members] : [];
    if (!members.includes(uid)) {
      throw new HttpsError("permission-denied", "Not a league member");
    }

    const teamCount = Number(data.teamCount || 8);
    const draftOrder = await ensureDraftOrderInTransaction(
        transaction,
        leagueRef,
        data,
        members,
        teamCount,
    );

    return {
      leagueId,
      teamCount,
      memberCount: members.length,
      draftOrder,
    };
  });
});

exports.finalizeFantasyLeague = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const leagueId = `${(request.data && request.data.leagueId) || ""}`.trim();
  if (!leagueId) {
    throw new HttpsError("invalid-argument", "leagueId is required");
  }

  const draftBoard = Array.isArray(request.data && request.data.draftBoard) ?
    request.data.draftBoard :
    [];
  const fantasyTeams = Array.isArray(request.data && request.data.fantasyTeams) ?
    request.data.fantasyTeams :
    [];
  const fantasySchedule = Array.isArray(
      request.data && request.data.fantasySchedule,
  ) ?
    request.data.fantasySchedule :
    [];

  const leagueRef = db.collection("leagues").doc(leagueId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(leagueRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "League not found");
    }

    const data = snapshot.data() || {};
    const members = Array.isArray(data.members) ? [...data.members] : [];
    if (!members.includes(uid)) {
      throw new HttpsError("permission-denied", "Not a league member");
    }

    if (data.fantasyReady === true &&
        Array.isArray(data.fantasyTeams) &&
        Array.isArray(data.fantasySchedule)) {
      return {
        leagueId,
        fantasyReady: true,
        fantasyTeams: data.fantasyTeams,
        fantasySchedule: data.fantasySchedule,
        draftBoard: Array.isArray(data.draftBoard) ? data.draftBoard : [],
      };
    }

    transaction.update(leagueRef, {
      fantasyReady: true,
      fantasyTeams,
      fantasySchedule,
      draftBoard,
      fantasyFinalizedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      leagueId,
      fantasyReady: true,
      fantasyTeams,
      fantasySchedule,
      draftBoard,
    };
  });
});

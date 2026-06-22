const {
  onRequest,
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
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
const FIXTURE_FIRESTORE_CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const KBO_LIVE_UPDATES_TTL_MS = 20 * 1000;
const KBO_MATCHES_UPDATES_INTV_SEC = 9000;
const KBO_OFFICIAL_SCOREBOARD_URL =
  "https://www.koreabaseball.com/Schedule/ScoreBoard.aspx";
const DSG_CLIENTS_BASE_URL = "https://dsg-api.com/clients";
const KBO_COMPETITION_ID = 1088;
const KBO_SEASON_ID = 78635;

let leagueCache = null;
let kboLeagueCache = null;
let kboLiveUpdatesCache = null;
let kboPeopleUpdatesCache = null;
let kboSeasonDetailedMatchesCache = null;
let kboFrozenCancelledMatchesCache = null;
const teamStatsCache = new Map();
const fixtureDetailsCache = new Map();
const kboMatchDetailsCache = new Map();
const kboMatchDayCache = new Map();
const kboOfficialScoreboardCache = new Map();
const kboSquadCache = new Map();
const kboPeopleDetailCache = new Map();
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
  PITCHER: "P",
  "STARTING PITCHER": "P",
  "RELIEF PITCHER": "P",
  CATCHER: "C",
  "FIRST BASEMAN": "1B",
  "SECOND BASEMAN": "2B",
  "THIRD BASEMAN": "3B",
  SHORTSTOP: "SS",
  "LEFT FIELDER": "LF",
  "CENTER FIELDER": "CF",
  "RIGHT FIELDER": "RF",
  OUTFIELDER: "OF",
  INFIELDER: "IF",
  "DESIGNATED HITTER": "DH",
};

const KOREA_TIME_OFFSET_MS = 9 * 60 * 60 * 1000;
const KBO_LOCK_MATCH_DURATION_MS = 4 * 60 * 60 * 1000;
const KBO_DAILY_UNLOCK_DELAY_MS = 5 * 60 * 60 * 1000;
const PUSH_EVENT_COLLECTION = "systemPushEvents";
const PUSH_STATE_COLLECTION = "systemPushState";
const KBO_FROZEN_CANCELLED_MATCH_COLLECTION =
  "systemKboFrozenCancelledMatches";
const PUSH_EVENT_WINDOW_MS = 15 * 60 * 1000;
const KBO_FANTASY_TOTAL_ROUNDS_2026 = 24;
const KBO_FANTASY_ROUND_WINDOWS_2026 = [
  { round: 1, startKst: "2026-03-28", endKst: "2026-03-29" },
  { round: 2, startKst: "2026-03-31", endKst: "2026-04-05" },
  { round: 3, startKst: "2026-04-07", endKst: "2026-04-12" },
  { round: 4, startKst: "2026-04-14", endKst: "2026-04-19" },
  { round: 5, startKst: "2026-04-21", endKst: "2026-04-26" },
  { round: 6, startKst: "2026-04-28", endKst: "2026-05-03" },
  { round: 7, startKst: "2026-05-05", endKst: "2026-05-10" },
  { round: 8, startKst: "2026-05-12", endKst: "2026-05-17" },
  { round: 9, startKst: "2026-05-19", endKst: "2026-05-24" },
  { round: 10, startKst: "2026-05-26", endKst: "2026-05-31" },
  { round: 11, startKst: "2026-06-02", endKst: "2026-06-07" },
  { round: 12, startKst: "2026-06-09", endKst: "2026-06-14" },
  { round: 13, startKst: "2026-06-16", endKst: "2026-06-21" },
  { round: 14, startKst: "2026-06-23", endKst: "2026-06-28" },
  { round: 15, startKst: "2026-06-30", endKst: "2026-07-05" },
  { round: 16, startKst: "2026-07-07", endKst: "2026-07-09" },
  { round: 17, startKst: "2026-07-16", endKst: "2026-07-19" },
  { round: 18, startKst: "2026-07-21", endKst: "2026-07-26" },
  { round: 19, startKst: "2026-07-28", endKst: "2026-08-02" },
  { round: 20, startKst: "2026-08-04", endKst: "2026-08-09" },
  { round: 21, startKst: "2026-08-11", endKst: "2026-08-16" },
  { round: 22, startKst: "2026-08-18", endKst: "2026-08-23" },
  { round: 23, startKst: "2026-08-25", endKst: "2026-08-30" },
  { round: 24, startKst: "2026-09-01", endKst: "2026-09-06" },
];

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
      errors: (error.response &&
        error.response.data &&
        error.response.data.errors) || { message: error.message },
    };
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function hasOptionalSectionData(payload) {
  return (
    Array.isArray(payload && payload.response) && payload.response.length > 0
  );
}

async function refetchOptionalSection(path, params = {}, attempts = 2) {
  let last = { response: [], errors: { message: "empty" } };
  for (let attempt = 0; attempt < attempts; attempt++) {
    last = await apiSportsGetOptional(path, params);
    if (hasOptionalSectionData(last)) return last;
    if (attempt < attempts - 1) {
      await sleep(250 * (attempt + 1));
    }
  }
  return last;
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
  return { client, username, password, authkey };
}

/**
 * Calls Datasportsgroup baseball v3.
 * @param {string} method endpoint method
 * @param {Object} params query parameters
 * @return {Promise<Object>} API response body
 */
async function dsgBaseballGet(method, params = {}) {
  const { client, username, password, authkey } = getDsgCredentials();
  const baseUrl = `${DSG_CLIENTS_BASE_URL}/${encodeURIComponent(client)}`;
  const response = await axios.get(`${baseUrl}/baseball/${method}`, {
    params: {
      ...params,
      client,
      authkey,
      ftype: "json",
    },
    auth: { username, password },
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
  return `${value == null ? "" : value}`
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function hasKoreanBatchim(value) {
  const text = `${value == null ? "" : value}`.trim();
  if (!text) return false;
  const code = text.charCodeAt(text.length - 1);
  if (code < 0xac00 || code > 0xd7a3) return false;
  return (code - 0xac00) % 28 !== 0;
}

function koreanParticle(value, { withBatchim, withoutBatchim }) {
  return hasKoreanBatchim(value) ? withBatchim : withoutBatchim;
}

function withKoreanParticle(value, particles) {
  const text = `${value == null ? "" : value}`.trim();
  if (!text) return "";
  return `${text}${koreanParticle(text, particles)}`;
}

function sanitizePublicUserProfile(data, fallbackUid = "") {
  const uid = `${(data && data.uid) || fallbackUid || ""}`.trim();
  const displayName = `${(data && data.displayName) || ""}`
    .trim()
    .replace(/\s+/g, " ");
  const normalizedDisplayName = `${(data && data.normalizedDisplayName) || ""}`
    .trim()
    .toLowerCase();
  const photoUrl = `${(data && data.photoUrl) || ""}`.trim();
  return {
    uid,
    displayName,
    normalizedDisplayName,
    photoUrl,
  };
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
 * Converts a Firestore timestamp-like value to epoch milliseconds.
 * @param {*} value timestamp-like value
 * @return {?number} epoch milliseconds
 */
function timestampToMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  const parsed = Date.parse(`${value}`);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeFcmTokens(value) {
  const tokens = Array.isArray(value) ? value : [value];
  return [...new Set(tokens
    .map((token) => `${token == null ? "" : token}`.trim())
    .filter(Boolean))];
}

function chunkArray(items, chunkSize) {
  const chunks = [];
  for (let index = 0; index < items.length; index += chunkSize) {
    chunks.push(items.slice(index, index + chunkSize));
  }
  return chunks;
}

function sanitizePushData(data = {}) {
  return Object.entries(data).reduce((acc, [key, value]) => {
    const normalizedKey = `${key || ""}`.trim();
    if (!normalizedKey) return acc;
    acc[normalizedKey] = `${value == null ? "" : value}`;
    return acc;
  }, {});
}

function isAlreadyExistsError(error) {
  return (
    error &&
    (error.code === 6 ||
      error.code === "already-exists" ||
      `${error.message || ""}`.toLowerCase().includes("already exists"))
  );
}

async function claimPushEvent(eventId, payload = {}) {
  const normalizedId = `${eventId || ""}`.trim();
  if (!normalizedId) return false;
  try {
    await db.collection(PUSH_EVENT_COLLECTION).doc(normalizedId).create({
      eventId: normalizedId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      ...payload,
    });
    return true;
  } catch (error) {
    if (isAlreadyExistsError(error)) return false;
    throw error;
  }
}

async function loadPushState(stateId) {
  const normalizedId = `${stateId || ""}`.trim();
  if (!normalizedId) return null;
  const snapshot = await db.collection(PUSH_STATE_COLLECTION).doc(normalizedId).get();
  if (!snapshot.exists) return null;
  return snapshot.data() || null;
}

async function writePushState(stateId, payload = {}) {
  const normalizedId = `${stateId || ""}`.trim();
  if (!normalizedId) return;
  await db.collection(PUSH_STATE_COLLECTION).doc(normalizedId).set({
    ...payload,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function loadPushTargetsForUids(uids) {
  const normalizedUids = [...new Set((Array.isArray(uids) ? uids : [])
    .map((uid) => `${uid || ""}`.trim())
    .filter(Boolean))];
  if (!normalizedUids.length) return [];
  const snapshots = await Promise.all(
    normalizedUids.map((uid) => db.collection("users").doc(uid).get()),
  );
  return snapshots
    .filter((snapshot) => snapshot.exists)
    .map((snapshot) => ({
      uid: snapshot.id,
      ...(snapshot.data() || {}),
    }))
    .filter((data) => data.pushEnabled !== false)
    .map((data) => {
      const tokens = normalizeFcmTokens([
        ...(Array.isArray(data.fcmTokens) ? data.fcmTokens : []),
        data.lastFcmToken,
      ]);
      const updatedAt =
        data.pushTokenUpdatedAt &&
        typeof data.pushTokenUpdatedAt.toMillis === "function" ?
          data.pushTokenUpdatedAt.toMillis() :
          Number.parseInt(`${data.pushTokenUpdatedAt || "0"}`, 10) || 0;
      return {
        uid: data.uid || "",
        tokens,
        updatedAt,
      };
    })
    .filter((target) => target.tokens.length > 0);
}

function latestOwnedPushTokensByUid(targets) {
  const tokenOwners = new Map();
  for (const target of Array.isArray(targets) ? targets : []) {
    const uid = `${(target && target.uid) || ""}`.trim();
    if (!uid) continue;
    const updatedAt = Number(target && target.updatedAt) || 0;
    const tokens = Array.isArray(target && target.tokens) ? target.tokens : [];
    for (const token of tokens) {
      const normalizedToken = `${token || ""}`.trim();
      if (!normalizedToken) continue;
      const previous = tokenOwners.get(normalizedToken);
      if (!previous || updatedAt >= previous.updatedAt) {
        tokenOwners.set(normalizedToken, { uid, updatedAt });
      }
    }
  }

  const tokensByUid = new Map();
  for (const [token, owner] of tokenOwners.entries()) {
    if (!tokensByUid.has(owner.uid)) {
      tokensByUid.set(owner.uid, []);
    }
    tokensByUid.get(owner.uid).push(token);
  }
  return tokensByUid;
}

async function sendPushNotificationToTokens({
  tokens,
  title,
  body,
  eventId = "",
  data = {},
}) {
  const allTokens = [...new Set((Array.isArray(tokens) ? tokens : [])
    .map((token) => `${token || ""}`.trim())
    .filter(Boolean))];
  if (!allTokens.length) {
    return { successCount: 0, failureCount: 0, targets: 0 };
  }

  const payloadData = sanitizePushData({
    ...data,
    ...(eventId ? { eventId: `${eventId}` } : {}),
  });
  let successCount = 0;
  let failureCount = 0;
  for (const chunk of chunkArray(allTokens, 500)) {
    const response = await admin.messaging().sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data: payloadData,
      android: {
        priority: "high",
        notification: {
          channelId: "leagueit_general",
          sound: "default",
        },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });
    successCount += response.successCount || 0;
    failureCount += response.failureCount || 0;
  }
  return {
    successCount,
    failureCount,
    targets: allTokens.length,
  };
}

async function sendPushNotificationToUids({
  uids,
  title,
  body,
  eventId = "",
  data = {},
}) {
  const targets = await loadPushTargetsForUids(uids);
  const tokenMap = latestOwnedPushTokensByUid(targets);
  let successCount = 0;
  let failureCount = 0;
  let targetsCount = 0;
  for (const [uid, tokens] of tokenMap.entries()) {
    const normalizedUid = `${uid || ""}`.trim();
    const ownedTokens = Array.isArray(tokens) ? tokens : [];
    if (!normalizedUid || !ownedTokens.length) continue;
    const response = await sendPushNotificationToTokens({
      tokens: ownedTokens,
      title,
      body,
      eventId,
      data: {
        ...data,
        uid: normalizedUid,
      },
    });
    successCount += response.successCount || 0;
    failureCount += response.failureCount || 0;
    targetsCount += response.targets || 0;
  }
  return {
    successCount,
    failureCount,
    targets: targetsCount,
  };
}

function kboMatchHasStarted(match, nowMs) {
  const kickoffMs = parseKboMatchKickoffMs(match);
  if (Number.isFinite(kickoffMs) && kickoffMs <= nowMs) return true;
  const status = `${(match && match.status) || ""}`.trim().toLowerCase();
  return (
    status === "playing" ||
    status === "live" ||
    isKboTerminalStatus(status)
  );
}

function extractBaseballFantasyPlayerIdentity(player) {
  const explicitId = `${(player && player.playerId) || ""}`.trim();
  if (explicitId) return explicitId;

  const club = normalizeKboTeamName(
    firstText(player && player.club, player && player.team),
  );
  const number =
    Number.parseInt(`${(player && player.number) || "0"}`, 10) || 0;
  const normalizedName = normalizeText(
    normalizeKboPlayerName(firstText(player && player.name)),
  );

  if (club && number > 0) {
    return `${normalizeText(club)}|${number}|${normalizedName}`;
  }
  if (club && normalizedName) {
    return `${normalizeText(club)}|${normalizedName}`;
  }
  return normalizedName;
}

function isBaseballCaptainForTeam(team, player) {
  const playerId = extractBaseballFantasyPlayerIdentity(player);
  const captainPlayerId = `${(team && team.captainPlayerId) || ""}`.trim();
  if (captainPlayerId) return captainPlayerId === playerId;

  const captainName = normalizeText(
    normalizeKboPlayerName(firstText(team && team.captainName)),
  );
  const playerName = normalizeText(
    normalizeKboPlayerName(firstText(player && player.name)),
  );
  return !!captainName && captainName === playerName;
}

function addKboFantasyScoreLookupEntry(map, key, score) {
  const normalizedKey = `${key || ""}`.trim();
  if (!normalizedKey) return;
  map.set(
    normalizedKey,
    roundFantasyPoints((map.get(normalizedKey) || 0) + score),
  );
}

function buildKboFantasyPlayerScoreLookup(playerStats) {
  const lookup = new Map();
  for (const player of Array.isArray(playerStats) ? playerStats : []) {
    const score = roundFantasyPoints(
      Number(player && player.fantasy && player.fantasy.points) || 0,
    );
    if (score === 0) continue;

    const teamName = normalizeKboTeamName(firstText(player && player.team));
    const teamKey = normalizeText(teamName);
    const number =
      Number.parseInt(`${(player && player.number) || "0"}`, 10) || 0;
    const normalizedName = normalizeText(
      normalizeKboPlayerName(firstText(player && player.name)),
    );
    const explicitId = `${(player && player.playerId) || ""}`.trim();

    addKboFantasyScoreLookupEntry(lookup, explicitId, score);
    addKboFantasyScoreLookupEntry(
      lookup,
      buildKboPlayerIdentity({
        teamId: firstText(player && player.teamId),
        teamName,
        playerId: explicitId,
        number,
        name: firstText(player && player.name),
      }),
      score,
    );
    if (teamKey && number > 0) {
      addKboFantasyScoreLookupEntry(lookup, `${teamKey}:${number}`, score);
    }
    if (teamKey && normalizedName) {
      addKboFantasyScoreLookupEntry(
        lookup,
        `${teamKey}:${normalizedName}`,
        score,
      );
    }
  }
  return lookup;
}

function addKboFantasyPlayerLookupEntry(map, key, player) {
  const normalizedKey = `${key || ""}`.trim();
  if (!normalizedKey || map.has(normalizedKey)) return;
  map.set(normalizedKey, player);
}

function buildKboFantasyPlayerStatLookup(playerStats) {
  const lookup = new Map();
  for (const player of Array.isArray(playerStats) ? playerStats : []) {
    const teamName = normalizeKboTeamName(firstText(player && player.team));
    const teamKey = normalizeText(teamName);
    const number =
      Number.parseInt(`${(player && player.number) || "0"}`, 10) || 0;
    const normalizedName = normalizeText(
      normalizeKboPlayerName(firstText(player && player.name)),
    );
    const explicitId = `${(player && player.playerId) || ""}`.trim();

    addKboFantasyPlayerLookupEntry(lookup, explicitId, player);
    addKboFantasyPlayerLookupEntry(
      lookup,
      buildKboPlayerIdentity({
        teamId: firstText(player && player.teamId),
        teamName,
        playerId: explicitId,
        number,
        name: firstText(player && player.name),
      }),
      player,
    );
    if (teamKey && number > 0) {
      addKboFantasyPlayerLookupEntry(lookup, `${teamKey}:${number}`, player);
    }
    if (teamKey && normalizedName) {
      addKboFantasyPlayerLookupEntry(
        lookup,
        `${teamKey}:${normalizedName}`,
        player,
      );
    }
  }
  return lookup;
}

function resolveKboFantasyRosterPlayerScore(player, lookup) {
  const club = normalizeKboTeamName(
    firstText(player && player.club, player && player.team),
  );
  const teamKey = normalizeText(club);
  const number =
    Number.parseInt(`${(player && player.number) || "0"}`, 10) || 0;
  const name = firstText(player && player.name);
  const explicitId = `${(player && player.playerId) || ""}`.trim();
  const normalizedName = normalizeText(normalizeKboPlayerName(name));
  const candidates = [
    explicitId,
    buildKboPlayerIdentity({
      teamName: club,
      playerId: explicitId,
      number,
      name,
    }),
    teamKey && number > 0 ? `${teamKey}:${number}` : "",
    teamKey && normalizedName ? `${teamKey}:${normalizedName}` : "",
  ];
  for (const candidate of candidates) {
    if (!candidate) continue;
    if (lookup.has(candidate)) return roundFantasyPoints(lookup.get(candidate));
  }
  return 0;
}

function resolveKboFantasyRosterPlayerStat(player, lookup) {
  const club = normalizeKboTeamName(
    firstText(player && player.club, player && player.team),
  );
  const teamKey = normalizeText(club);
  const number =
    Number.parseInt(`${(player && player.number) || "0"}`, 10) || 0;
  const name = firstText(player && player.name);
  const explicitId = `${(player && player.playerId) || ""}`.trim();
  const normalizedName = normalizeText(normalizeKboPlayerName(name));
  const candidates = [
    explicitId,
    buildKboPlayerIdentity({
      teamName: club,
      playerId: explicitId,
      number,
      name,
    }),
    teamKey && number > 0 ? `${teamKey}:${number}` : "",
    teamKey && normalizedName ? `${teamKey}:${normalizedName}` : "",
  ];
  for (const candidate of candidates) {
    if (!candidate) continue;
    if (lookup.has(candidate)) return lookup.get(candidate);
  }
  return null;
}

function parseKboHomeRunRunsFromText(text) {
  const normalized = normalizeText(text).replace(/[-_]/g, " ");
  if (!normalized) return null;
  if (
    normalized.includes("grand slam") ||
    normalized.includes("만루") ||
    normalized.includes("grand-slam")
  ) {
    return 4;
  }
  if (
    normalized.includes("three run") ||
    normalized.includes("3 run") ||
    normalized.includes("쓰리런") ||
    normalized.includes("3점")
  ) {
    return 3;
  }
  if (
    normalized.includes("two run") ||
    normalized.includes("2 run") ||
    normalized.includes("투런") ||
    normalized.includes("2점")
  ) {
    return 2;
  }
  if (
    normalized.includes("solo") ||
    normalized.includes("솔로") ||
    normalized.includes("1점")
  ) {
    return 1;
  }
  const match = /([1-4])\s*(?:run|점)/.exec(normalized);
  if (!match) return null;
  return Number.parseInt(match[1], 10) || null;
}

function extractKboHomeRunEvents(match) {
  return collectDsgValues(match, "event")
    .map((raw) => (raw && typeof raw === "object" ? raw : null))
    .filter(Boolean)
    .map((event) => {
      const text = [
        firstText(event.type, event.event_type),
        firstText(event.detail, event.event_detail, event.description),
        firstText(
          event.commentary,
          event.text,
          event.result,
          event.play_result,
          event.event_result,
          event.action,
        ),
      ].filter(Boolean).join(" ");
      const normalizedText = normalizeText(text);
      if (
        !normalizedText.includes("home run") &&
        !normalizedText.includes("homerun") &&
        !normalizedText.includes("homer") &&
        !normalizedText.includes("홈런")
      ) {
        return null;
      }
      const rawRunValue =
        Number.parseInt(
          firstText(
            event.run_count,
            event.runs,
            event.points,
            event.point,
            event.rbi,
            event.event_extra && event.event_extra.run_count,
            event.event_extra && event.event_extra.runs,
            event.event_extra && event.event_extra.points,
          ),
          10,
        ) || 0;
      const runs = Math.max(
        1,
        Math.min(4, rawRunValue || parseKboHomeRunRunsFromText(text) || 1),
      );
      const team = readKboDetailTeamName(event, match);
      const name = normalizeKboPlayerName(readKboPersonName(event));
      if (!team || !name) return null;
      return {
        team: normalizeText(team),
        name: normalizeText(name),
        runs,
      };
    })
    .filter(Boolean);
}

function kboPlayerIsPitcher(player) {
  if (!player || typeof player !== "object") return false;
  const position = normalizeKboPosition(firstText(player.position));
  const innings = Number(player.pitching && player.pitching.inningsPitched) || 0;
  return position === "P" || innings > 0;
}

function kboRosterPlayerIsPitcher(player) {
  if (!player || typeof player !== "object") return false;
  return normalizeKboPosition(firstText(player.position)) === "P";
}

function completedKboPitcherInningMilestone(player) {
  const innings =
    Number(player && player.pitching && player.pitching.inningsPitched) || 0;
  if (!Number.isFinite(innings) || innings < 1) return 0;
  return Math.floor(innings + 1e-9);
}

function resolveKboHomeRunRunValue(playerStat, homeRunEvents) {
  const team = normalizeText(
    normalizeKboTeamName(firstText(playerStat && playerStat.team)),
  );
  const name = normalizeText(
    normalizeKboPlayerName(firstText(playerStat && playerStat.name)),
  );
  const matchedRuns = (Array.isArray(homeRunEvents) ? homeRunEvents : [])
    .filter((event) => event && event.team === team && event.name === name)
    .map((event) => Number(event.runs) || 0)
    .filter((value) => value > 0);
  if (matchedRuns.length) {
    return Math.max(...matchedRuns);
  }
  const homeRuns = Number(playerStat && playerStat.batting && playerStat.batting.homeRuns) || 0;
  const rbi = Number(playerStat && playerStat.batting && playerStat.batting.rbi) || 0;
  if (homeRuns > 0 && rbi > 0) {
    return Math.max(1, Math.min(4, Math.round(rbi / homeRuns)));
  }
  return 1;
}

function hasMatchedKboHomeRunEvent(playerStat, homeRunEvents) {
  const team = normalizeText(
    normalizeKboTeamName(firstText(playerStat && playerStat.team)),
  );
  const name = normalizeText(
    normalizeKboPlayerName(firstText(playerStat && playerStat.name)),
  );
  return (Array.isArray(homeRunEvents) ? homeRunEvents : []).some((event) => {
    return event && event.team === team && event.name === name;
  });
}

function buildBaseballFptsPushMessage({
  leagueName,
  playerName,
  displayedScore,
  playerStat,
  rosterPosition,
  homeRunEvents,
}) {
  if (!playerStat) return null;
  if (
    normalizeKboPosition(firstText(rosterPosition)) === "P" ||
    kboPlayerIsPitcher(playerStat)
  ) {
    return {
      title: `${leagueName} Fpts 업데이트⚾️💥`,
      body:
        `${withKoreanParticle(playerName, { withBatchim: "이", withoutBatchim: "가" })} ` +
        `${displayedScore.toFixed(1)} Fpts를 기록했습니다.`,
    };
  }
  const homeRuns =
    Number(playerStat.batting && playerStat.batting.homeRuns) || 0;
  if (homeRuns <= 0 || !hasMatchedKboHomeRunEvent(playerStat, homeRunEvents)) {
    return null;
  }
  const runValue = resolveKboHomeRunRunValue(playerStat, homeRunEvents);
  return {
    title: `${leagueName} Fpts 업데이트⚾️💥`,
    body:
      `${withKoreanParticle(playerName, { withBatchim: "이", withoutBatchim: "가" })} ` +
      `${runValue}점 홈런을 기록했습니다.`,
  };
}

async function loadPreviousPitcherPushDisplayedScore({
  leagueId,
  uid,
  fantasyRound,
  identity,
  pitcherMilestone,
}) {
  for (let milestone = pitcherMilestone - 1; milestone >= 1; milestone -= 1) {
    const eventId =
      `fpts_pitcher:${leagueId}:${uid}:${fantasyRound}:${identity}:${milestone}`;
    const snapshot = await db.collection(PUSH_EVENT_COLLECTION).doc(eventId).get();
    if (!snapshot.exists) continue;
    const data = snapshot.data() || {};
    const displayedScore = Number(data.displayedScore);
    if (Number.isFinite(displayedScore)) {
      return displayedScore;
    }
  }
  return 0;
}

function buildSoccerGoalCandidateKeys(player, club) {
  const keys = [];
  const explicitId = `${(player && player.playerId) || ""}`.trim();
  if (explicitId) keys.push(explicitId);
  const canonicalClub = canonicalKLeagueClub(
    kLeagueDisplayTeamName(firstText(player && player.club, club)),
  );
  const normalizedName = normalizeText(firstText(player && player.name));
  if (canonicalClub && normalizedName) {
    keys.push(`${canonicalClub}|${normalizedName}`);
  }
  return [...new Set(keys.filter(Boolean))];
}

function fantasyPushEligiblePlayers(team) {
  const starting = Array.isArray(team && team.starting) ?
    team.starting.filter((player) => player && typeof player === "object") :
    [];
  const roster = Array.isArray(team && team.roster) ?
    team.roster.filter((player) => player && typeof player === "object") :
    [];
  if (!roster.length) return starting;

  const rosterIds = new Set(
    roster.map((player) => extractFantasyPlayerIdentity(player)).filter(Boolean),
  );
  if (!rosterIds.size) return starting;

  const filtered = starting.filter((player) => {
    const identity = extractFantasyPlayerIdentity(player);
    return identity && rosterIds.has(identity);
  });
  if (filtered.length !== starting.length) {
    console.log(
      `Filtered stale soccer push starters for uid=${(team && team.uid) || ""} ` +
      `team=${(team && team.teamName) || ""} starting=${starting.length} eligible=${filtered.length}`,
    );
  }
  return filtered;
}

function fantasyBaseballPushEligiblePlayers(team) {
  const starting = fantasyPushEligiblePlayers(team);
  const roster = Array.isArray(team && team.roster) ?
    team.roster.filter((player) => player && typeof player === "object") :
    [];
  if (!roster.length) return starting;

  const rosterIds = new Set(
    roster.map((player) => extractBaseballFantasyPlayerIdentity(player)).filter(Boolean),
  );
  if (!rosterIds.size) return starting;

  const filtered = starting.filter((player) => {
    const identity = extractBaseballFantasyPlayerIdentity(player);
    return identity && rosterIds.has(identity);
  });
  if (filtered.length !== starting.length) {
    console.log(
      `Filtered stale baseball push starters for uid=${(team && team.uid) || ""} ` +
      `team=${(team && team.teamName) || ""} starting=${starting.length} eligible=${filtered.length}`,
    );
  }
  return filtered;
}

function kboFantasyRosterPlayers(team) {
  const combined = [
    ...(Array.isArray(team && team.roster) ? team.roster : []),
    ...(Array.isArray(team && team.starting) ? team.starting : []),
    ...(Array.isArray(team && team.bench) ? team.bench : []),
  ];
  const unique = new Map();
  for (const player of combined) {
    if (!player || typeof player !== "object") continue;
    const identity = extractBaseballFantasyPlayerIdentity(player);
    if (!identity || unique.has(identity)) continue;
    unique.set(identity, player);
  }
  return Array.from(unique.values());
}

function activeFantasyTeamsForMembers(fantasyTeams, members) {
  const memberSet = new Set(
    (Array.isArray(members) ? members : [])
      .map((uid) => `${uid || ""}`.trim())
      .filter(Boolean),
  );
  if (!memberSet.size) return [];
  const draftOrder = arguments.length > 2 ? arguments[2] : [];
  const draftUidByName = new Map(
    (Array.isArray(draftOrder) ? draftOrder : [])
      .map((entry) => {
        const uid = `${(entry && entry.uid) || ""}`.trim();
        const displayName = normalizeText(`${(entry && entry.displayName) || ""}`);
        return [displayName, uid];
      })
      .filter(([displayName, uid]) => !!displayName && !!uid && memberSet.has(uid)),
  );
  const teams = Array.isArray(fantasyTeams) ? fantasyTeams : [];
  const filtered = teams
    .map((team) => {
      const rawTeam = team && typeof team === "object" ? { ...team } : {};
      const explicitUid = `${rawTeam.uid || ""}`.trim();
      if (explicitUid && memberSet.has(explicitUid)) {
        return rawTeam;
      }
      const fallbackUid = draftUidByName.get(
        normalizeText(`${rawTeam.teamName || ""}`),
      );
      if (!fallbackUid) return null;
      return {
        ...rawTeam,
        uid: fallbackUid,
      };
    })
    .filter(Boolean);
  if (filtered.length !== teams.length) {
    console.log(
      `Filtered inactive fantasy teams for push dispatch total=${teams.length} active=${filtered.length}`,
    );
  }
  return filtered;
}

function currentKboRoundTodayMatches({
  draftDateMs,
  roundCount,
  rawMatches,
  nowMs,
}) {
  const fantasyRound = currentFantasyBaseballRoundAt({
    draftDateMs,
    roundCount,
    nowMs,
  });
  if (!kboFantasyRoundHasStarted({ draftDateMs, fantasyRound, nowMs })) {
    return [];
  }
  const targetRound = mappedKboRoundForFantasyRound({
    draftDateMs,
    fantasyRound,
  });
  const todayKey = kstDateKeyFromMs(nowMs);
  return (Array.isArray(rawMatches) ? rawMatches : [])
    .filter(
      (match) =>
        kboFantasyRoundForDateKey(kboMatchDateKey(match)) === targetRound,
    )
    .filter((match) => kboMatchDateKey(match) === todayKey);
}

function groupTodayKboMatchesByKickoff({
  draftDateMs,
  roundCount,
  rawMatches,
  nowMs,
}) {
  const groups = new Map();
  currentKboRoundTodayMatches({
    draftDateMs,
    roundCount,
    rawMatches,
    nowMs,
  }).forEach((match) => {
    const kickoffMs = parseKboMatchKickoffMs(match);
    if (!Number.isFinite(kickoffMs) || kickoffMs <= 0) return;
    const key = `${kickoffMs}`;
    if (!groups.has(key)) {
      groups.set(key, {
        kickoffMs,
        clubs: new Set(),
        matchIds: [],
      });
    }
    const group = groups.get(key);
    group.matchIds.push(`${(match && match.id) || ""}`.trim());
    group.clubs.add(normalizeKboTeamName((match && match.home) || ""));
    group.clubs.add(normalizeKboTeamName((match && match.away) || ""));
  });
  return Array.from(groups.values()).sort((a, b) => a.kickoffMs - b.kickoffMs);
}

function kboRosterAffectedPlayerNames(team, lockedClubs) {
  const targetClubs = lockedClubs instanceof Set ? lockedClubs : new Set();
  if (!team || !targetClubs.size) return [];
  const names = [];
  const seenNames = new Set();
  for (const player of fantasyBaseballPushEligiblePlayers(team)) {
    const club = normalizeKboTeamName(
      firstText(player && player.club, player && player.team),
    );
    const normalizedClub = normalizeText(club);
    const matchesClub = [...targetClubs].some(
      (value) => normalizeText(value) === normalizedClub,
    );
    if (!matchesClub) continue;
    const name = normalizeKboPlayerName(firstText(player && player.name));
    if (!name || seenNames.has(name)) continue;
    seenNames.add(name);
    names.push(name);
  }
  return names;
}

function buildKboRosterTimingBody({
  leagueName,
  playerNames,
  isSoon,
}) {
  const names = Array.isArray(playerNames) ? playerNames.filter(Boolean) : [];
  if (!names.length) {
    return isSoon ?
      `${leagueName} 로스터가 30분 내 일부 잠깁니다.` :
      `${leagueName} 일부 선수가 잠겼습니다.`;
  }
  if (names.length === 1) {
    return isSoon ?
      `${names[0]} 선수가 30분 뒤 잠깁니다.` :
      `${names[0]} 선수가 잠겼습니다.`;
  }
  return isSoon ?
    `${names[0]} 외 ${names.length - 1}명의 선수가 30분 뒤 잠깁니다.` :
    `${names[0]} 외 ${names.length - 1}명의 선수가 잠겼습니다.`;
}

async function sendKboRosterTimingPushToMembers({
  members,
  fantasyTeams,
  draftOrder,
  leagueId,
  leagueName,
  round,
  title,
  type,
  eventId,
  clubs,
  isSoon,
}) {
  const resolvedFantasyTeams = activeFantasyTeamsForMembers(
    fantasyTeams,
    members,
    draftOrder,
  );
  const teamByUid = new Map(
    resolvedFantasyTeams
      .map((team) => [`${(team && team.uid) || ""}`.trim(), team])
      .filter(([uid]) => !!uid),
  );
  const pushTargets = await loadPushTargetsForUids(members);
  const tokensByUid = latestOwnedPushTokensByUid(pushTargets);
  let successCount = 0;
  let failureCount = 0;
  let targetsCount = 0;
  for (const uid of Array.isArray(members) ? members : []) {
    const normalizedUid = `${uid || ""}`.trim();
    if (!normalizedUid) continue;
    const ownedTokens = tokensByUid.get(normalizedUid) || [];
    if (!ownedTokens.length) continue;
    const playerNames = kboRosterAffectedPlayerNames(
      teamByUid.get(normalizedUid),
      clubs,
    );
    if (!playerNames.length) continue;
    const body = buildKboRosterTimingBody({
      leagueName,
      playerNames,
      isSoon,
    });
    const response = await sendPushNotificationToTokens({
      tokens: ownedTokens,
      title,
      body,
      eventId,
      data: {
        type,
        leagueId,
        round: `${round}`,
        leagueName,
        sport: "baseball",
        uid: normalizedUid,
      },
    });
    successCount += response.successCount || 0;
    failureCount += response.failureCount || 0;
    targetsCount += response.targets || 0;
  }
  return {
    successCount,
    failureCount,
    targets: targetsCount,
  };
}

function buildSoccerGoalEventLookup(detail) {
  const lookup = new Map();
  const events = Array.isArray(detail && detail.events) ? detail.events : [];
  for (const raw of events) {
    const event = raw && typeof raw === "object" ? raw : {};
    const type = `${event.type || ""}`.trim();
    const detailText = `${event.detail || ""}`.trim();
    if (type !== "Goal") continue;
    if (detailText === "Own Goal" || detailText === "Missed Penalty") continue;

    const player = event.player && typeof event.player === "object"
      ? event.player
      : {};
    const team = event.team && typeof event.team === "object" ? event.team : {};
    const playerId = `${player.id || ""}`.trim();
    const playerName = `${player.name || ""}`.trim();
    const club = canonicalKLeagueClub(
      kLeagueDisplayTeamName(firstText(team.name)),
    );
    if (!playerId && (!playerName || !club)) continue;

    const eventPayload = {
      fixtureId: `${detail && detail.fixtureId ? detail.fixtureId : ""}`.trim(),
      playerId,
      playerName,
      club,
    };
    if (playerId) {
      lookup.set(playerId, eventPayload);
    }
    const normalizedName = normalizeText(playerName);
    if (club && normalizedName) {
      lookup.set(`${club}|${normalizedName}`, eventPayload);
    }
  }
  return lookup;
}

async function maybeDispatchSoccerGoalPush({
  leagueId,
  leagueName,
  fantasyTeams,
  draftDateMs,
  roundCount,
  rawFixtures,
  nowMs,
}) {
  const fantasyRound = currentFantasySoccerRoundAt({
    draftDateMs,
    roundCount,
    rawFixtures,
    nowMs,
  });
  const targetRound = mappedKLeagueRoundForFantasyRound({
    draftDateMs,
    fantasyRound,
    rawFixtures,
  });
  const startedRoundFixtures = (Array.isArray(rawFixtures) ? rawFixtures : [])
    .filter((fixture) => {
      const league = fixture && fixture.league && typeof fixture.league === "object"
        ? fixture.league
        : {};
      return parseRoundNumber(league.round || "") === targetRound;
    })
    .filter((fixture) => fixtureHasStarted(fixture, nowMs));
  if (!startedRoundFixtures.length) return;

  const detailPayloads = await Promise.all(
    startedRoundFixtures.map(async (fixture) => {
      const fixtureId =
        Number.parseInt(`${(fixture && fixture.fixture && fixture.fixture.id) || "0"}`, 10) || 0;
      if (fixtureId <= 0) return null;
      try {
        return await fetchFixtureDetails(fixtureId);
      } catch (error) {
        console.error(
          `Soccer goal push detail load failed for league ${leagueId} fixture ${fixtureId}:`,
          error,
        );
        return null;
      }
    }),
  );
  const goalLookup = new Map();
  for (const detail of detailPayloads.filter(Boolean)) {
    for (const [key, value] of buildSoccerGoalEventLookup(detail).entries()) {
      goalLookup.set(key, value);
    }
  }
  if (!goalLookup.size) return;

  for (const team of Array.isArray(fantasyTeams) ? fantasyTeams : []) {
    const uid = `${(team && team.uid) || ""}`.trim();
    if (!uid) continue;

    for (const player of fantasyPushEligiblePlayers(team)) {
      const rosterIdentity = extractFantasyPlayerIdentity(player);
      if (!rosterIdentity) continue;
      const matchedGoal = buildSoccerGoalCandidateKeys(player).reduce(
        (found, key) => found || goalLookup.get(key) || null,
        null,
      );
      if (!matchedGoal) continue;

      const eventId =
        `fpts_goal:${leagueId}:${uid}:${matchedGoal.fixtureId}:${rosterIdentity}`;
      const claimed = await claimPushEvent(eventId, {
        kind: "fpts_goal",
        leagueId,
        uid,
        round: fantasyRound,
        fixtureId: matchedGoal.fixtureId,
        playerId: rosterIdentity,
      });
      if (!claimed) continue;

      const playerName = `${(player && player.name) || matchedGoal.playerName || ""}`.trim();
      if (!playerName) continue;
      await sendPushNotificationToUids({
        uids: [uid],
        title: `${leagueName} Fpts 업데이트⚽️💥`,
        body:
          `${withKoreanParticle(playerName, { withBatchim: "이", withoutBatchim: "가" })} ` +
          `득점을 기록했습니다.`,
        eventId,
        data: {
          type: "fpts",
          leagueId,
          leagueName,
          round: `${fantasyRound}`,
          sport: "soccer",
        },
      });
    }
  }
}

async function maybeDispatchBaseballFptsPush({
  leagueId,
  leagueName,
  fantasyTeams,
  draftDateMs,
  roundCount,
  kboLeagueData,
  rawMatches,
  nowMs,
}) {
  const fantasyRound = currentFantasyBaseballRoundAt({
    draftDateMs,
    roundCount,
    nowMs,
  });
  if (!kboFantasyRoundHasStarted({ draftDateMs, fantasyRound, nowMs })) {
    return;
  }

  const targetRound = mappedKboRoundForFantasyRound({
    draftDateMs,
    fantasyRound,
  });
  const frozenCancelledRounds = buildFrozenKboCancelledMatchRoundMap(
    kboLeagueData,
  );
  const startedRoundMatches = (Array.isArray(rawMatches) ? rawMatches : [])
    .filter(
      (match) => {
        const matchId =
          Number.parseInt(`${(match && match.id) || "0"}`, 10) || 0;
        const originalRound =
          matchId > 0 ? frozenCancelledRounds.get(`${matchId}`) || 0 : 0;
        if (originalRound > 0 && originalRound !== targetRound) {
          return false;
        }
        return kboFantasyRoundForDateKey(kboMatchDateKey(match)) === targetRound;
      },
    )
    .filter((match) => kboMatchHasStarted(match, nowMs));
  if (!startedRoundMatches.length) return;

  const detailPayloads = await Promise.all(
    startedRoundMatches.map(async (match) => {
      const matchId =
        Number.parseInt(`${(match && match.id) || "0"}`, 10) || 0;
      if (matchId <= 0) return null;
      try {
        const detail = await fetchKboMatchDetails(matchId, {
          preferFreshLiveData: true,
        });
        return {
          playerStats: Array.isArray(detail && detail.playerStats) ?
            detail.playerStats :
            [],
          homeRunEvents: Array.isArray(detail && detail.homeRunEvents) ?
            detail.homeRunEvents :
            [],
        };
      } catch (error) {
        console.error(
          `KBO Fpts push detail load failed for league ${leagueId} match ${matchId}:`,
          error,
        );
        return null;
      }
    }),
  );
  const aggregatedPlayerStats = mergeKboPlayerEntries(
    detailPayloads.flatMap((payload) =>
      Array.isArray(payload && payload.playerStats) ? payload.playerStats : [],
    ),
  ).map((player) => ({
    ...player,
    fantasy: buildKboFantasyBreakdown(player),
  }));
  const homeRunEvents = detailPayloads.flatMap((payload) =>
    Array.isArray(payload && payload.homeRunEvents) ? payload.homeRunEvents : [],
  );
  const scoreLookup = buildKboFantasyPlayerScoreLookup(aggregatedPlayerStats);
  const statLookup = buildKboFantasyPlayerStatLookup(aggregatedPlayerStats);
  if (!scoreLookup.size) return;

  for (const team of Array.isArray(fantasyTeams) ? fantasyTeams : []) {
    const uid = `${(team && team.uid) || ""}`.trim();
    if (!uid) continue;

    const uniqueRoster = new Map();
    for (const player of fantasyBaseballPushEligiblePlayers(team)) {
      const identity = extractBaseballFantasyPlayerIdentity(player);
      if (!identity || uniqueRoster.has(identity)) continue;
      uniqueRoster.set(identity, player);
    }

    for (const [identity, player] of uniqueRoster.entries()) {
      const baseScore = resolveKboFantasyRosterPlayerScore(player, scoreLookup);
      const displayedScore = isBaseballCaptainForTeam(team, player) ?
        roundFantasyPoints(baseScore * 2) :
        baseScore;
      const playerStat = resolveKboFantasyRosterPlayerStat(player, statLookup);
      const isPitcherPush =
        kboRosterPlayerIsPitcher(player) || kboPlayerIsPitcher(playerStat);
      const pitcherMilestone = isPitcherPush ?
        completedKboPitcherInningMilestone(playerStat) :
        0;
      if (isPitcherPush && pitcherMilestone <= 0) continue;
      if (!isPitcherPush && displayedScore <= 0) continue;

      let pushDisplayedScore = displayedScore;
      const pitcherStateId =
        `kbo_pitcher:${leagueId}:${uid}:${fantasyRound}:${identity}`;
      let previousPitcherMilestone = 0;
      let previousPitcherDisplayedScore = 0;
      if (isPitcherPush) {
        const pitcherState = await loadPushState(pitcherStateId);
        previousPitcherMilestone =
          Number(pitcherState && pitcherState.pitcherMilestone) || 0;
        previousPitcherDisplayedScore = roundFantasyPoints(
          Number(pitcherState && pitcherState.displayedScore) || 0,
        );
        const skippedMilestones =
          previousPitcherMilestone > 0 &&
          pitcherMilestone > previousPitcherMilestone + 1;
        const missingBaseline =
          previousPitcherMilestone <= 0 && pitcherMilestone > 1;
        if (skippedMilestones || missingBaseline) {
          console.log(
            `Skipping cumulative pitcher push for ${player && player.name || identity} ` +
            `league=${leagueId} uid=${uid} round=${fantasyRound} ` +
            `previousMilestone=${previousPitcherMilestone} currentMilestone=${pitcherMilestone} ` +
            `displayedScore=${displayedScore.toFixed(1)}`,
          );
          await writePushState(pitcherStateId, {
            leagueId,
            uid,
            fantasyRound,
            identity,
            pitcherMilestone,
            displayedScore,
          });
          continue;
        }
        pushDisplayedScore = roundFantasyPoints(
          displayedScore - previousPitcherDisplayedScore,
        );
        if (pushDisplayedScore <= 0.001) {
          console.log(
            `Suppressing non-positive pitcher push for ${player && player.name || identity} ` +
            `league=${leagueId} uid=${uid} round=${fantasyRound} ` +
            `milestone=${pitcherMilestone} delta=${pushDisplayedScore.toFixed(1)}`,
          );
          await writePushState(pitcherStateId, {
            leagueId,
            uid,
            fantasyRound,
            identity,
            pitcherMilestone,
            displayedScore,
          });
          continue;
        }
      }

      const playerName = `${(player && player.name) || ""}`.trim();
      const pushMessage = buildBaseballFptsPushMessage({
        leagueName,
        playerName,
        displayedScore: pushDisplayedScore,
        playerStat,
        rosterPosition: player && player.position,
        homeRunEvents,
      });
      if (!pushMessage) continue;

      const eventId = isPitcherPush ?
        `fpts_pitcher:${leagueId}:${uid}:${fantasyRound}:${identity}:${pitcherMilestone}` :
        `fpts:${leagueId}:${uid}:${fantasyRound}:${identity}`;
      const claimed = await claimPushEvent(eventId, {
        kind: "fpts",
        leagueId,
        uid,
        round: fantasyRound,
        playerId: identity,
        pitcherMilestone,
        displayedScore,
        pushDisplayedScore,
      });
      if (isPitcherPush) {
        await writePushState(pitcherStateId, {
          leagueId,
          uid,
          fantasyRound,
          identity,
          pitcherMilestone,
          displayedScore,
        });
      }
      if (!claimed) continue;
      await sendPushNotificationToUids({
        uids: [uid],
        title: pushMessage.title,
        body: pushMessage.body,
        eventId,
        data: {
          type: "fpts",
          leagueId,
          leagueName,
          round: `${fantasyRound}`,
          sport: "baseball",
        },
      });
    }
  }
}

/**
 * Reads one cached fixture detail document from Firestore if it is still fresh.
 * @param {string} fixtureId fixture id string
 * @return {Promise<?Object>} cached payload without metadata
 */
async function readFixtureDetailsFirestoreCache(fixtureId) {
  const snapshot = await db.collection("fixtureCache").doc(fixtureId).get();
  if (!snapshot.exists) return null;
  const data = snapshot.data() || {};
  const cachedAtMs = timestampToMillis(data.cachedAt);
  if (
    !cachedAtMs ||
    Date.now() - cachedAtMs >= FIXTURE_FIRESTORE_CACHE_TTL_MS
  ) {
    return null;
  }
  const { cachedAt, ...payload } = data;
  return payload;
}

function fixtureDetailsHasCriticalData(payload) {
  return (
    asArray(payload && payload.lineups).length > 0 ||
    asArray(payload && payload.players).length > 0
  );
}

function fixtureDetailsHasRenderableEventData(payload) {
  return asArray(payload && payload.events).length > 0;
}

function fixtureDetailsStatusShort(payload) {
  const fixture = payload && payload.fixture;
  const fixtureMeta = fixture && fixture.fixture;
  const status = fixtureMeta && fixtureMeta.status;
  return `${(status && status.short) || ""}`.trim().toUpperCase();
}

function fixtureDetailsIsFinal(payload) {
  return ["FT", "AET", "PEN"].includes(fixtureDetailsStatusShort(payload));
}

function shouldReuseFirestoreFixtureDetails(payload) {
  if (!fixtureDetailsIsFinal(payload)) return false;
  return (
    fixtureDetailsHasCriticalData(payload) &&
    fixtureDetailsHasRenderableEventData(payload)
  );
}

/**
 * Persists one fixture detail response to Firestore for cross-request reuse.
 * @param {string} fixtureId fixture id string
 * @param {Object} data normalized fixture details payload
 * @return {Promise<void>}
 */
async function writeFixtureDetailsFirestoreCache(fixtureId, data) {
  await db
    .collection("fixtureCache")
    .doc(fixtureId)
    .set({
      ...data,
      cachedAt: admin.firestore.Timestamp.now(),
    });
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

function decodeHtmlEntities(value) {
  return `${value || ""}`
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&#x27;/gi, "'");
}

function cleanKboOfficialHtmlText(value) {
  return decodeHtmlEntities(`${value || ""}`.replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
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
  const candidatePaths = [
    path.resolve(__dirname, "..", "docs", "kbo_players_season_2026.txt"),
    path.join(__dirname, "kbo_players_season_2026.txt"),
  ];
  const filePath =
    candidatePaths.find((candidate) => fs.existsSync(candidate)) ||
    candidatePaths[candidatePaths.length - 1];

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
        existingDisplayName &&
        existingDisplayName !== englishName &&
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

  kboPlayerDirectoryCache = { names, byTeamNumber, byTeam, candidates };
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
  if (/^\d+$/.test(raw)) return "";
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

  leagueCache = { createdAt: Date.now(), data };
  return data;
}

/**
 * Pulls KBO season information from Datasportsgroup response shape.
 * @param {Object} data raw seasons response
 * @return {?Object} season object
 */
function extractKboSeason(data) {
  const competition = ((data || {}).datasportsgroup || {}).competition || {};
  const season = competition.season;
  return (
    asArray(season).find((entry) => {
      return `${entry.season_id}` === `${KBO_SEASON_ID}`;
    }) ||
    asArray(season)[0] ||
    null
  );
}

/**
 * Pulls KBO round information from Datasportsgroup response shape.
 * @param {Object} data raw rounds response
 * @return {Array<Object>} round objects
 */
function extractKboRounds(data) {
  const root = ((data || {}).datasportsgroup || {}).competition || {};
  const season = root.season || {};
  return asArray(season.round);
}

/**
 * Pulls KBO standings rows from Datasportsgroup response shape.
 * @param {Object} data raw tables response
 * @return {Array<Object>} table rows
 */
function extractKboTable(data) {
  const root = ((data || {}).datasportsgroup || {}).tour || {};
  const tourSeason = root.tour_season || {};
  const competition = tourSeason.competition || {};
  const season = competition.season || {};
  const round = season.round || {};
  const total = round.total || {};
  return asArray(total.table);
}

function isKboStandingsRow(row) {
  if (!row || typeof row !== "object" || Array.isArray(row)) return false;
  const values = row.values && typeof row.values === "object" ? row.values : {};
  const statistics =
    row.statistics && typeof row.statistics === "object" ? row.statistics : {};
  return !!(
    firstText(row.team_name, row.short_name, row.name) &&
    (firstText(row.team_id, row.position, row.rank, row.id) ||
      Object.keys(values).length > 0 ||
      Object.keys(statistics).length > 0 ||
      firstText(
        values.matches_total,
        values.matches_won,
        values.matches_lost,
        values.games_behind,
        statistics.matches_total,
        statistics.matches_won,
        statistics.matches_lost,
        statistics.games_behind,
        row.matches_total,
        row.matches_won,
        row.matches_lost,
        row.games_behind,
      ))
  );
}

function extractKboTableLoose(data) {
  const direct = extractKboTable(data).filter(isKboStandingsRow);
  if (direct.length) return direct;

  const nestedTables = collectDsgValues(data, "table").filter(isKboStandingsRow);
  if (nestedTables.length) return nestedTables;

  const discovered = [
    ...collectDsgValues(data, "standing"),
    ...collectDsgValues(data, "row"),
  ].filter(isKboStandingsRow);
  if (discovered.length) return discovered;

  const recursive = [];
  const seen = new Set();
  const visit = (entry) => {
    if (!entry || typeof entry !== "object") return;
    if (Array.isArray(entry)) {
      entry.forEach(visit);
      return;
    }
    if (isKboStandingsRow(entry)) {
      const key = [
        firstText(entry.team_id, entry.id),
        firstText(entry.team_name, entry.short_name, entry.name),
        firstText(entry.position, entry.rank),
      ].join("|");
      if (!seen.has(key)) {
        seen.add(key);
        recursive.push(entry);
      }
    }
    Object.values(entry).forEach(visit);
  };
  visit(data);
  return recursive;
}

/**
 * Pulls KBO match rows from Datasportsgroup response shape.
 * @param {Object} data raw matches response
 * @return {Array<Object>} match rows
 */
function extractKboMatches(data) {
  const root = ((data || {}).datasportsgroup || {}).tour || {};
  const tourSeason = root.tour_season || {};
  const competition = tourSeason.competition || {};
  const season = competition.season || {};
  const discipline = season.discipline || {};
  const gender = discipline.gender || {};
  const round = gender.round || {};
  const list = round.list || {};
  return asArray(list.match);
}

function extractKboMatchesLoose(data) {
  const direct = extractKboMatches(data);
  if (direct.length) return direct;

  return collectDsgValues(data, "match").filter((row) => {
    return (
      row &&
      typeof row === "object" &&
      !Array.isArray(row) &&
      firstText(row.match_id, row.id) &&
      firstText(row.team_a_id, row.team_b_id, row.team_a_name, row.team_b_name)
    );
  });
}

async function fetchKboMatchesDay(day) {
  const cacheKey = `${day}`;
  const cached = kboMatchDayCache.get(cacheKey);
  const ttlMs =
    cacheKey === kstDateKeyFromMs(Date.now())
      ? KBO_LIVE_UPDATES_TTL_MS
      : CACHE_TTL_MS;
  if (isCacheFreshFor(cached, ttlMs)) return cached.data;

  const data = await dsgBaseballGetOptional("get_matches_day", {
    day,
    detailed: "yes",
  });
  const output = extractKboMatchesLoose(data);
  kboMatchDayCache.set(cacheKey, { createdAt: Date.now(), data: output });
  return output;
}

async function fetchKboSeasonDetailedMatches() {
  if (isCacheFresh(kboSeasonDetailedMatchesCache)) {
    return kboSeasonDetailedMatchesCache.data;
  }

  const data = await dsgBaseballGetOptional("get_matches", {
    type: "season",
    id: KBO_SEASON_ID,
    detailed: "yes",
  });
  const output = extractKboMatchesLoose(data);
  kboSeasonDetailedMatchesCache = { createdAt: Date.now(), data: output };
  return output;
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
  return asArray(rows)
    .map((row) => {
      const values =
        (row.values && typeof row.values === "object" ? row.values : null) ||
        (row.statistics && typeof row.statistics === "object"
          ? row.statistics
          : null) ||
        {};
      const runsFor = toInt(values.runs_for || row.runs_for);
      const runsAgainst = toInt(values.runs_against || row.runs_against);
      return {
        rank: toInt(row.position || row.rank),
        teamId: `${row.team_id || row.id || ""}`,
        team: normalizeKboTeamName(row.team_name || row.short_name || row.name),
        apiTeamName: row.team_name || row.short_name || row.name || "",
        played: toInt(values.matches_total || row.matches_total),
        wins: toInt(values.matches_won || row.matches_won),
        draws: toInt(values.matches_tied || row.matches_tied),
        losses: toInt(values.matches_lost || row.matches_lost),
        runsFor,
        runsAgainst,
        runsDiff: toInt(
          values.runs_difference || row.runs_difference || runsFor - runsAgainst,
        ),
        percentage: Number(values.percentage || row.percentage || 0),
        gamesBehind: `${values.games_behind || row.games_behind || "0"}`,
        home: `${values.home || ""}`,
        road: `${values.road || ""}`,
        streak: normalizeKboStreak(row.form),
      };
    })
    .sort((a, b) => {
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
  return asArray(matches)
    .map((match) => {
      const venue = (match.match_extra || {}).venue || match.venue || {};
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
        liveInningLabel: extractKboLiveInningLabel(match),
        winner: `${match.winner || ""}`,
        homeScore: toNullableNumber(match.score_a),
        awayScore: toNullableNumber(match.score_b),
        lastUpdated: `${match.last_updated || ""}`,
        venue: `${venue.venue_name || ""}`,
        city: `${venue.venue_city || ""}`,
      };
    })
    .sort((a, b) => {
      const left = `${a.date} ${a.time} ${a.id}`;
      const right = `${b.date} ${b.time} ${b.id}`;
      return left.localeCompare(right);
    });
}

function normalizeKboInningLabel(value) {
  const raw = `${value || ""}`.trim();
  if (!raw) return "";
  if (raw.includes("회")) return raw;
  const digits = raw.match(/\d+/);
  if (digits && digits.length) return `${digits[0]}회`;
  return raw;
}

function isKboLiveInningLabel(value) {
  return /회/.test(`${value || ""}`.trim());
}

function extractKboLiveInningLabel(match) {
  const innings = normalizeKboInnings(match);
  if (innings.length) {
    return normalizeKboInningLabel(innings[innings.length - 1].label);
  }
  return normalizeKboInningLabel(
    firstText(
      match && match.current_inning,
      match && match.inning,
      match && match.period,
      match && match.period_number,
      match && match.match_extra && match.match_extra.current_inning,
      match && match.match_extra && match.match_extra.inning,
    ),
  );
}

function buildKboLiveInningMap(matches) {
  const byId = new Map();
  asArray(matches).forEach((match) => {
    const matchId = firstText(match && match.match_id, match && match.id);
    const liveInningLabel = extractKboLiveInningLabel(match);
    if (!matchId || !liveInningLabel) return;
    byId.set(`${matchId}`, liveInningLabel);
  });
  return byId;
}

function kboOfficialScoreboardMatchKey(awayTeam, homeTeam) {
  return `${normalizeText(awayTeam)}|${normalizeText(homeTeam)}`;
}

function extractKboOfficialScoreboardMatches(html) {
  const rows = [];
  const rowPattern =
    /<p class='leftTeam'>[\s\S]*?<strong class='teamT'>([^<]+)<\/strong>[\s\S]*?<strong class="flag"><span[^>]*>([^<]*)<\/span><\/strong>[\s\S]*?<p class='rightTeam'>[\s\S]*?<strong class='teamT'>([^<]+)<\/strong>[\s\S]*?<p class="place">([\s\S]*?)<\/p>/g;
  let match;
  while ((match = rowPattern.exec(`${html || ""}`)) !== null) {
    const away = normalizeKboTeamName(cleanKboOfficialHtmlText(match[1]));
    const liveInningLabel = normalizeKboInningLabel(
      cleanKboOfficialHtmlText(match[2]),
    );
    const home = normalizeKboTeamName(cleanKboOfficialHtmlText(match[3]));
    const place = cleanKboOfficialHtmlText(
      `${match[4] || ""}`.replace(/<span[\s\S]*?<\/span>/i, " "),
    );
    if (!away || !home) continue;
    rows.push({
      away,
      home,
      place,
      liveInningLabel: isKboLiveInningLabel(liveInningLabel) ?
        liveInningLabel :
        "",
    });
  }
  return rows;
}

function buildKboOfficialScoreboardMap(matches) {
  const byTeams = new Map();
  asArray(matches).forEach((match) => {
    if (!match || !match.away || !match.home || !match.liveInningLabel) return;
    byTeams.set(
      kboOfficialScoreboardMatchKey(match.away, match.home),
      match.liveInningLabel,
    );
  });
  return byTeams;
}

async function fetchKboOfficialScoreboardDay(dayKey) {
  const cacheKey = `${dayKey || ""}`.trim();
  if (!cacheKey) return [];
  const cached = kboOfficialScoreboardCache.get(cacheKey);
  const ttlMs =
    cacheKey === kstDateKeyFromMs(Date.now()) ?
      KBO_LIVE_UPDATES_TTL_MS :
      CACHE_TTL_MS;
  if (isCacheFreshFor(cached, ttlMs)) return cached.data;

  try {
    const response = await axios.get(KBO_OFFICIAL_SCOREBOARD_URL, {
      params: { date: cacheKey.replace(/-/g, "") },
      responseType: "text",
    });
    const output = extractKboOfficialScoreboardMatches(response.data);
    kboOfficialScoreboardCache.set(cacheKey, {
      createdAt: Date.now(),
      data: output,
    });
    return output;
  } catch (error) {
    console.error("fetchKboOfficialScoreboardDay failed", cacheKey, error);
    return cached && cached.data ? cached.data : [];
  }
}

/**
 * Pulls recently updated KBO match rows from Datasportsgroup response shape.
 * @param {Object} data raw updates response
 * @return {Array<Object>} updated match rows
 */
function extractKboUpdatedMatches(data) {
  return collectDsgValues(data, "match").filter(
    (row) => row && typeof row === "object",
  );
}

function extractKboUpdatedPeople(data) {
  const root = (data || {}).datasportsgroup || {};
  const rows = [
    ...asArray(root.people_updates),
    ...collectDsgValues(root.people_updates, "people"),
    ...collectDsgValues(root.people_updates, "person"),
    ...collectDsgValues(root.people_updates, "player"),
  ];
  return dedupeKboDetailRows(rows).filter((row) => {
    return row && typeof row === "object" && !Array.isArray(row);
  });
}

function readKboActiveMembershipTeam(row) {
  const memberships = [
    ...collectDsgValues(row, "membership"),
    ...asArray(row.membership),
  ].filter((item) => item && typeof item === "object");
  const activeMembership =
    memberships.find((membership) => {
      return firstText(membership.active).toLowerCase() === "yes";
    }) ||
    memberships[0] ||
    null;
  return normalizeKboTeamName(
    firstText(
      activeMembership && activeMembership.team_name,
      activeMembership && activeMembership.short_name,
    ),
  );
}

function normalizeKboUpdatedPeople(rows) {
  return asArray(rows)
    .map((row) => {
      const name = readKboPersonName(row);
      const peopleId = readKboPersonId(row);
      const team = readKboActiveMembershipTeam(row);
      const updatedAt = firstText(
        row.last_updated,
        row.people && row.people.last_updated,
      );
      return {
        peopleId,
        name,
        team,
        updatedAt,
        key: `${normalizeText(team)}|${normalizeText(name)}`,
      };
    })
    .filter((row) => row.peopleId && row.name);
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
    liveInningLabel: patch.liveInningLabel || base.liveInningLabel || "",
    winner: patch.winner || base.winner,
    homeScore:
      patch.homeScore !== undefined && patch.homeScore !== null
        ? patch.homeScore
        : base.homeScore,
    awayScore:
      patch.awayScore !== undefined && patch.awayScore !== null
        ? patch.awayScore
        : base.awayScore,
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
  if (
    isCacheFresh(kboLiveUpdatesCache) &&
    Date.now() - kboLiveUpdatesCache.createdAt < KBO_LIVE_UPDATES_TTL_MS
  ) {
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

  const output = { byId };
  kboLiveUpdatesCache = { createdAt: Date.now(), data: output };
  return output;
}

async function fetchKboPeopleUpdates() {
  if (isCacheFreshFor(kboPeopleUpdatesCache, KBO_LIVE_UPDATES_TTL_MS)) {
    return kboPeopleUpdatesCache.data;
  }

  const data = await dsgBaseballGetOptional("get_peoples_updates", {
    intv: 3600,
  });
  const people = normalizeKboUpdatedPeople(extractKboUpdatedPeople(data));
  const byKey = new Map(people.map((row) => [row.key, row]));
  const output = { people, byKey };
  kboPeopleUpdatesCache = { createdAt: Date.now(), data: output };
  return output;
}

function extractKboPersonDetail(data) {
  const root = (data || {}).datasportsgroup || {};
  return root.people && typeof root.people === "object" ? root : {};
}

async function fetchKboPersonDetail(peopleId) {
  const cacheKey = `${peopleId}`;
  const cached = kboPeopleDetailCache.get(cacheKey);
  if (isCacheFresh(cached)) return cached.data;

  const data = await dsgBaseballGetOptional("get_peoples", {
    id: peopleId,
    ml: 20,
  });
  const detail = extractKboPersonDetail(data);
  kboPeopleDetailCache.set(cacheKey, { createdAt: Date.now(), data: detail });
  return detail;
}

function kboPersonPlayedMatch(detail, matchId) {
  const root = (detail || {}).datasportsgroup || {};
  const matches = asArray(((root.people || {}).last_matches || {}).match);
  return matches.some((match) => `${match.match_id || ""}` === `${matchId}`);
}

async function shouldRefreshCachedKboMatchDetail(
  matchId,
  cachedData,
  createdAt,
) {
  const updates = await fetchKboPeopleUpdates();
  if (!updates.people.length) return false;

  const lineups = asArray(cachedData && cachedData.lineups);
  const candidates = [];
  lineups.forEach((lineup) => {
    const team = normalizeKboTeamName(lineup && lineup.team);
    asArray(lineup && lineup.players).forEach((player) => {
      const key = `${normalizeText(team)}|${normalizeText(player && player.name)}`;
      const updated = updates.byKey.get(key);
      if (
        updated &&
        !candidates.some((row) => row.peopleId === updated.peopleId)
      ) {
        candidates.push(updated);
      }
    });
    const pitcherName = firstText(lineup && lineup.starterPitcher);
    if (pitcherName) {
      const key = `${normalizeText(team)}|${normalizeText(pitcherName)}`;
      const updated = updates.byKey.get(key);
      if (
        updated &&
        !candidates.some((row) => row.peopleId === updated.peopleId)
      ) {
        candidates.push(updated);
      }
    }
  });

  for (const candidate of candidates.slice(0, 8)) {
    const updatedAtMs = Date.parse(candidate.updatedAt || "");
    if (Number.isFinite(updatedAtMs) && updatedAtMs <= createdAt) continue;
    const personDetail = await fetchKboPersonDetail(candidate.peopleId);
    if (kboPersonPlayedMatch(personDetail, matchId)) {
      return true;
    }
  }
  return false;
}

/**
 * Loads KBO live updates without failing the main schedule/detail screens.
 * @return {Promise<Object>} safe update maps
 */
async function fetchKboLiveUpdatesOptional() {
  try {
    return await fetchKboLiveUpdates();
  } catch (error) {
    console.error(
      "Unable to load KBO live updates",
      (error.response && error.response.data) || error.message,
    );
    return kboLiveUpdatesCache ? kboLiveUpdatesCache.data : { byId: new Map() };
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
    row.common_name_local,
  );
  if (localName) return localName;

  return normalizeKboPlayerName(
    firstText(
      row.common_name,
      row.short_name,
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
    row.shirtnumber,
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
  const candidates = [
    row.event_extra && row.event_extra.match_position_1,
    row.event_extra && row.event_extra.match_position_2,
    row.event_extra && row.event_extra.pitching_position,
    row.match_position_1,
    row.match_position_2,
    row.pitching_position,
    row.position,
    row.position_name,
    row.position_short,
    row.field_position,
    row.role,
  ];
  for (const candidate of candidates) {
    const normalized = normalizeKboPosition(candidate);
    if (normalized) return normalized;
  }
  return "";
}

function readKboBattingOrder(row) {
  return firstText(
    row.batting_order,
    row.batting_position,
    row.batting_position_sub,
    row.bat_order,
    row.lineup_order,
    row.order,
    row.sequence,
    row.sortorder,
    row.betting_order,
    row.betting_position,
    row.event_extra && row.event_extra.batting_order,
    row.event_extra && row.event_extra.batting_position,
    row.event_extra && row.event_extra.batting_position_sub,
    row.event_extra && row.event_extra.bat_order,
    row.event_extra && row.event_extra.lineup_order,
    row.event_extra && row.event_extra.order,
    row.event_extra && row.event_extra.sequence,
    row.event_extra && row.event_extra.sortorder,
    row.event_extra && row.event_extra.betting_order,
    row.event_extra && row.event_extra.betting_position,
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
    row.team,
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

function dedupeKboDetailRows(rows) {
  const deduped = [];
  const seen = new Set();
  rows.forEach((row) => {
    if (
      !row ||
      typeof row !== "object" ||
      Array.isArray(row) ||
      seen.has(row)
    ) {
      return;
    }
    seen.add(row);
    deduped.push(row);
  });
  return deduped;
}

function collectKboDetailEventRows(value) {
  const rows = [];
  const push = (row) => {
    if (row && typeof row === "object" && !Array.isArray(row)) {
      rows.push(row);
    }
  };

  asArray(value).forEach((entry) => {
    push(entry);
    collectDsgValues(entry, "event").forEach(push);
    collectDsgValues(entry, "people").forEach(push);
    collectDsgValues(entry, "person").forEach(push);
    collectDsgValues(entry, "player").forEach(push);
  });

  return rows;
}

function collectKboDetailPeopleRows(match) {
  const events = (match && match.events) || {};
  return dedupeKboDetailRows([
    ...collectDsgValues(match, "people"),
    ...collectDsgValues(match, "person"),
    ...collectDsgValues(match, "player"),
    ...collectKboDetailEventRows(events.lineups),
    ...collectKboDetailEventRows(events.subs_on_bench),
    ...collectKboDetailEventRows(events.probable_pitchers),
  ]).filter((row) => {
    return row && typeof row === "object" && !Array.isArray(row);
  });
}

function collectKboFallbackDetailPeopleRows(match) {
  return dedupeKboDetailRows([
    ...collectDsgValues(match, "people"),
    ...collectDsgValues(match, "person"),
    ...collectDsgValues(match, "player"),
  ]).filter((row) => {
    return row && typeof row === "object" && !Array.isArray(row);
  });
}

function collectKboPlayerStatRows(match) {
  const rows = [];
  const push = (value) => {
    asArray(value).forEach((row) => {
      if (row && typeof row === "object") rows.push(row);
    });
  };

  const playerStats = (match && match.player_stats) || {};
  push(playerStats);
  push(playerStats.people);
  push(playerStats.person);
  push(playerStats.player);
  push(playerStats.stat);

  return dedupeKboDetailRows([
    ...rows,
    ...collectDsgValues(playerStats, "people"),
    ...collectDsgValues(playerStats, "person"),
    ...collectDsgValues(playerStats, "player"),
    ...collectDsgValues(match, "people"),
    ...collectDsgValues(match, "person"),
    ...collectDsgValues(match, "player"),
    ...collectDsgValues(match, "player_stats"),
  ]).filter((row) => {
    return row && typeof row === "object" && !Array.isArray(row);
  });
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
  const rows = periods
    .map((period, index) => {
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
    })
    .filter((row) => row.home || row.away);

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

  return rows
    .map((row) => {
      const teamName = normalizeKboTeamName(
        firstText(row.team_name, row.club_name, row.competitor_name),
      );
      const number = readKboUniformNumber(row);
      return {
        playerId: readKboPersonId(row),
        name: readKboPersonName(row),
        number,
        position: readKboPosition(row),
        teamId: firstText(row.team_id, row.club_id, row.competitor_id),
        team: teamName,
      };
    })
    .filter((row) => row.name);
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
  const byTeam = new Map(
    Array.from(directory.byTeam.entries()).map(([key, value]) => [
      key,
      [...value],
    ]),
  );

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

  return { byId, byTeamNumber, byName, byTeam };
}

/**
 * Returns a stable sort order for baseball positions.
 * @param {string} position normalized position
 * @return {number} priority
 */
function kboPositionPriority(position) {
  const priority = {
    P: 0,
    C: 1,
    "1B": 2,
    "2B": 3,
    "3B": 4,
    SS: 5,
    LF: 6,
    CF: 7,
    RF: 8,
    OF: 9,
    IF: 10,
    DH: 11,
  }[position];
  return priority === undefined ? 99 : priority;
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
  const rawPlayers =
    rosterLookup.byTeam.get(normalizeText(teamName)) ||
    rosterLookup.byTeam.get(`id:${teamId}`) ||
    [];
  const uniquePlayers = Array.from(
    new Map(
      rawPlayers.map((player) => {
        const key = `${normalizeText(player.name)}|${player.number}|${player.position}`;
        return [key, player];
      }),
    ).values(),
  ).sort((a, b) => {
    const positionOrder =
      kboPositionPriority(a.position) - kboPositionPriority(b.position);
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

function buildProjectedKboBench(
  teamName,
  teamId,
  rosterLookup,
  starters = [],
  starterPitcher = "",
) {
  const rawPlayers =
    rosterLookup.byTeam.get(normalizeText(teamName)) ||
    rosterLookup.byTeam.get(`id:${teamId}`) ||
    [];
  const starterNames = new Set(
    asArray(starters)
      .map((player) => normalizeText(player && player.name))
      .filter(Boolean),
  );
  const starterPitcherKey = normalizeText(starterPitcher);
  const uniquePlayers = Array.from(
    new Map(
      rawPlayers.map((player) => {
        const key = `${normalizeText(player.name)}|${player.number}|${player.position}`;
        return [key, player];
      }),
    ).values(),
  )
    .filter((player) => {
      const nameKey = normalizeText(player.name);
      if (!nameKey) return false;
      if (starterNames.has(nameKey)) return false;
      if (starterPitcherKey && nameKey === starterPitcherKey) return false;
      return true;
    })
    .sort((a, b) => {
      const positionOrder =
        kboPositionPriority(a.position) - kboPositionPriority(b.position);
      if (positionOrder !== 0) return positionOrder;
      const leftNumber = toInt(a.number) > 0 ? toInt(a.number) : 999;
      const rightNumber = toInt(b.number) > 0 ? toInt(b.number) : 999;
      if (leftNumber !== rightNumber) return leftNumber - rightNumber;
      return a.name.localeCompare(b.name, "ko");
    });

  return uniquePlayers.map((player) => ({
    name: player.name,
    position: player.position || "",
    number: player.number || "",
  }));
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
  kboSquadCache.set(cacheKey, { createdAt: Date.now(), data });
  return data;
}

/**
 * Normalizes KBO lineups from the detailed match payload.
 * @param {Object} match raw match
 * @param {Object} rosterLookup KBO roster lookup maps
 * @return {Array<Object>} normalized team lineups
 */
function normalizeKboLineups(match, rosterLookup = buildKboRosterLookup([])) {
  const events = (match && match.events) || {};
  const lineupRows = dedupeKboDetailRows(
    collectKboDetailEventRows(events.lineups),
  ).filter((row) => row && typeof row === "object" && !Array.isArray(row));
  const benchRows = dedupeKboDetailRows(
    collectKboDetailEventRows(events.subs_on_bench),
  ).filter((row) => row && typeof row === "object" && !Array.isArray(row));
  const probablePitcherRows = dedupeKboDetailRows(
    collectKboDetailEventRows(events.probable_pitchers),
  ).filter((row) => row && typeof row === "object" && !Array.isArray(row));
  const fallbackRows =
    lineupRows.length || benchRows.length || probablePitcherRows.length
      ? []
      : collectKboFallbackDetailPeopleRows(match);
  const starterRows = dedupeKboDetailRows([
    ...lineupRows,
    ...probablePitcherRows,
    ...fallbackRows,
  ]);

  const teams = new Map();
  const ensureTeam = (teamId, teamName) => {
    const key = firstText(teamId, teamName, "unknown");
    if (!teams.has(key)) {
      teams.set(key, {
        teamId: `${teamId || ""}`,
        team: teamName,
        starterPitcher: "",
        players: [],
        substitutes: [],
      });
    }
    return teams.get(key);
  };

  starterRows.forEach((row) => {
    const teamId = firstText(row.team_id, row.competitor_id, row.club_id);
    const teamName = readKboDetailTeamName(row, match);
    const roster = findKboRosterPlayer(row, rosterLookup, teamName, teamId);
    const name = readKboPersonName(roster || row) || readKboPersonName(row);
    if (!name) return;

    const position = readKboPosition(row) || (roster && roster.position) || "";
    const order = readKboBattingOrder(row);
    const team = ensureTeam(teamId, teamName);

    if (
      (position === "P" ||
        position === "SP" ||
        firstText(row.role).toLowerCase().includes("pitcher")) &&
      (isKboStarter(row) || !team.starterPitcher)
    ) {
      team.starterPitcher = name;
    }

    if (!order && !isKboStarter(row)) return;
    if (!order && position === "P") return;

    const numericOrder = Number(order);
    const duplicate = team.players.some((player) => {
      return (
        player.name === name ||
        `${player.order}` === `${numericOrder}`
      );
    });
    if (duplicate) return;

    team.players.push({
      order:
        Number.isFinite(numericOrder) && numericOrder > 0
          ? numericOrder
          : team.players.length + 1,
      name,
      position: position || firstText(row.role).toUpperCase(),
      number: readKboUniformNumber(row) || (roster && roster.number) || "",
    });
  });

  benchRows.forEach((row) => {
    const teamId = firstText(row.team_id, row.competitor_id, row.club_id);
    const teamName = readKboDetailTeamName(row, match);
    const roster = findKboRosterPlayer(row, rosterLookup, teamName, teamId);
    const name = readKboPersonName(roster || row) || readKboPersonName(row);
    if (!name) return;

    const team = ensureTeam(teamId, teamName);
    if (
      team.players.some((player) => player.name === name) ||
      team.substitutes.some((player) => player.name === name)
    ) {
      return;
    }

    team.substitutes.push({
      name,
      position:
        readKboPosition(row) || (roster && roster.position) || firstText(row.role).toUpperCase(),
      number: readKboUniformNumber(row) || (roster && roster.number) || "",
    });
  });

  const normalized = Array.from(teams.values())
    .map((team) => {
      const orderedPlayers = team.players.sort((a, b) => a.order - b.order);
      const overflowPlayers = orderedPlayers.slice(9).map((player) => ({
        name: player.name,
        position: player.position || "",
        number: player.number || "",
      }));
      const mergedSubstitutes = Array.from(
        new Map(
          [...team.substitutes, ...overflowPlayers].map((player) => {
            const key = `${normalizeText(player.name)}|${player.number}|${player.position}`;
            return [key, player];
          }),
        ).values(),
      );
      return {
        ...team,
        players: orderedPlayers.slice(0, 9),
        substitutes: mergedSubstitutes,
      };
    })
    .map((team) => {
      const projected = buildProjectedKboLineup(
        team.team,
        team.teamId,
        rosterLookup,
      );
      const shouldFallbackToProjected =
        team.players.length < 7 &&
        projected.players.length >= team.players.length;
      const effectivePlayers = shouldFallbackToProjected
        ? projected.players
        : team.players;
      const projectedBench = buildProjectedKboBench(
        team.team,
        team.teamId,
        rosterLookup,
        effectivePlayers,
        team.starterPitcher || projected.starterPitcher,
      );
      return {
        ...team,
        starterPitcher: team.starterPitcher || projected.starterPitcher,
        players: effectivePlayers,
        substitutes: team.substitutes.length
            ? team.substitutes
            : projectedBench,
        source: shouldFallbackToProjected ? "projected" : "official",
      };
    });

  const teamA = normalizeKboTeamName(match.team_a_name);
  const teamB = normalizeKboTeamName(match.team_b_name);
  const ordered = [teamA, teamB].map((name) => {
    return (
      normalized.find((lineup) => lineup.team === name) || {
        team: name,
        teamId: "",
        starterPitcher: "",
        players: [],
        substitutes: [],
        source: "",
      }
    );
  });
  return ordered;
}

function kboLineupStrength(lineup) {
  const players = asArray(lineup && lineup.players);
  const substitutes = asArray(lineup && lineup.substitutes);
  return {
    official: firstText(lineup && lineup.source) === "official",
    playerCount: players.length + substitutes.length,
  };
}

function isBetterKboLineup(candidate, current) {
  const left = kboLineupStrength(candidate);
  const right = kboLineupStrength(current);
  if (left.official !== right.official) return left.official;
  return left.playerCount > right.playerCount;
}

function mergeKboLineupSources(primary, alternate) {
  const alternateByTeam = new Map(
    asArray(alternate).map((lineup) => [normalizeText(lineup && lineup.team), lineup]),
  );
  return asArray(primary).map((lineup) => {
    const alt = alternateByTeam.get(normalizeText(lineup && lineup.team));
    return alt && isBetterKboLineup(alt, lineup) ? alt : lineup;
  });
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
    const target =
      teamName === normalizeKboTeamName(match.team_b_name)
        ? fields.away
        : fields.home;
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

function mergeKboPitchingSources(...sources) {
  const merged = {
    home: { name: "", result: "", saveName: "" },
    away: { name: "", result: "", saveName: "" },
  };

  sources.forEach((source) => {
    if (!source || typeof source !== "object") return;
    const normalized = normalizeKboPitching(source);
    for (const side of ["home", "away"]) {
      const current = merged[side];
      const next =
        normalized && normalized[side] && typeof normalized[side] === "object" ?
          normalized[side] :
          {};
      current.name = current.name || firstText(next.name);
      current.result = current.result || firstText(next.result);
      current.saveName = current.saveName || firstText(next.saveName);
    }
  });

  return merged;
}

function normalizeDsgStatKey(key) {
  return normalizeText(key).replace(/[^a-z0-9]/g, "");
}

function extractNestedStatNumber(value) {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return null;
    if (/^-?\d+(\.\d+)?$/.test(trimmed)) {
      const parsed = Number(trimmed);
      return Number.isFinite(parsed) ? parsed : null;
    }
    return null;
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      const parsed = extractNestedStatNumber(item);
      if (parsed !== null) return parsed;
    }
    return null;
  }
  if (typeof value === "object") {
    const directKeys = [
      "value",
      "total",
      "count",
      "stat",
      "number",
      "amount",
      "result",
    ];
    for (const key of directKeys) {
      const parsed = extractNestedStatNumber(value[key]);
      if (parsed !== null) return parsed;
    }
  }
  return null;
}

function collectDsgFieldValues(entry, aliases, results = []) {
  if (!entry || typeof entry !== "object") return results;
  const aliasSet = new Set(aliases.map(normalizeDsgStatKey));
  const visit = (value) => {
    if (!value || typeof value !== "object") return;
    if (Array.isArray(value)) {
      value.forEach(visit);
      return;
    }
    Object.entries(value).forEach(([key, child]) => {
      if (aliasSet.has(normalizeDsgStatKey(key))) {
        results.push(child);
      }
      visit(child);
    });
  };
  visit(entry);
  return results;
}

function firstDsgNumericStat(entry, aliases) {
  const values = collectDsgFieldValues(entry, aliases);
  for (const value of values) {
    const parsed = extractNestedStatNumber(value);
    if (parsed !== null) return parsed;
  }
  return 0;
}

function parseKboInningsPitched(value) {
  const text = `${value == null ? "" : value}`.trim();
  if (!text) return 0;
  const slashMatch = text.match(/^(\d+)\s+(\d+)\/(\d+)$/);
  if (slashMatch) {
    const whole = Number(slashMatch[1]);
    const numerator = Number(slashMatch[2]);
    const denominator = Number(slashMatch[3]);
    if (
      Number.isFinite(whole) &&
      Number.isFinite(numerator) &&
      Number.isFinite(denominator) &&
      denominator > 0
    ) {
      return whole + numerator / denominator;
    }
  }
  const decimalOutsMatch = text.match(/^(\d+)\.(\d)$/);
  if (decimalOutsMatch) {
    const whole = Number(decimalOutsMatch[1]);
    const outs = Number(decimalOutsMatch[2]);
    if (
      Number.isFinite(whole) &&
      Number.isFinite(outs) &&
      outs >= 0 &&
      outs <= 2
    ) {
      return whole + outs / 3;
    }
  }
  const parsed = Number(text);
  return Number.isFinite(parsed) ? parsed : 0;
}

function firstDsgInningsPitched(entry, aliases) {
  const values = collectDsgFieldValues(entry, aliases);
  for (const value of values) {
    const text = firstText(
      value,
      value && value.value,
      value && value.text,
      value && value.result,
    );
    if (!text) continue;
    const parsed = parseKboInningsPitched(text);
    if (parsed > 0) return parsed;
  }
  return 0;
}

function buildKboPlayerIdentity({ teamId, teamName, playerId, number, name }) {
  const teamKey = firstText(teamId, normalizeText(teamName), "unknown-team");
  const playerKey = firstText(
    playerId,
    number,
    normalizeText(name),
    "unknown-player",
  );
  return `${teamKey}|${playerKey}`;
}

function normalizeKboPitchingDecisionNames(match) {
  const winnerNames = new Set();
  const saveNames = new Set();
  const decisionPitcherName = (value) => {
    if (!value) return "";
    if (typeof value === "object") {
      return readKboPersonName(value);
    }
    return normalizeKboPlayerName(value);
  };
  const addWinner = (...values) => {
    values
      .map(decisionPitcherName)
      .filter(Boolean)
      .forEach((name) => {
        winnerNames.add(normalizeText(name));
      });
  };
  const addSaver = (...values) => {
    values
      .map(decisionPitcherName)
      .filter(Boolean)
      .forEach((name) => {
        saveNames.add(normalizeText(name));
      });
  };

  addWinner(
    match.winning_pitcher_a,
    match.win_pitcher_a,
    match.winning_pitcher_b,
    match.win_pitcher_b,
  );
  addSaver(
    match.save_pitcher_a,
    match.saving_pitcher_a,
    match.pitcher_save_a,
    match.save_a,
    match.save_pitcher_b,
    match.saving_pitcher_b,
    match.pitcher_save_b,
    match.save_b,
  );

  collectDsgValues(match, "event").forEach((event) => {
    const name = normalizeKboPlayerName(readKboPersonName(event));
    if (!name) return;
    const type = firstText(event.type, event.event_type).toLowerCase();
    const decision = firstText(event.decision, event.result).toLowerCase();
    if (decision.includes("win") || decision.includes("승")) {
      winnerNames.add(normalizeText(name));
    }
    if (
      decision.includes("save") ||
      decision.includes("sv") ||
      decision.includes("세") ||
      type.includes("save")
    ) {
      saveNames.add(normalizeText(name));
    }
  });

  return { winnerNames, saveNames };
}

function roundFantasyPoints(value) {
  return Math.round(value * 100) / 100;
}

function mergeKboPlayerEntries(players) {
  const merged = new Map();

  players.forEach((player) => {
    if (!player || !player.name) return;
    const teamKey = firstText(
      player.teamId,
      normalizeText(player.team),
      "unknown-team",
    );
    const nameKey = normalizeText(player.name);
    const bucketKey = `${teamKey}|${nameKey}`;
    const previous = merged.get(bucketKey) || {
      teamId: `${player.teamId || ""}`,
      team: player.team || "",
      playerId: `${player.playerId || ""}`,
      name: player.name,
      number: `${player.number || ""}`,
      position: player.position || "",
      started: false,
      batting: {
        singles: 0,
        doubles: 0,
        triples: 0,
        homeRuns: 0,
        rbi: 0,
        runs: 0,
        walks: 0,
        hitByPitch: 0,
        stolenBases: 0,
        strikeouts: 0,
      },
      pitching: {
        inningsPitched: 0,
        strikeouts: 0,
        wins: 0,
        losses: 0,
        saves: 0,
        earnedRuns: 0,
        walks: 0,
      },
    };

    previous.teamId = previous.teamId || `${player.teamId || ""}`;
    previous.team = previous.team || player.team || "";
    previous.playerId = previous.playerId || `${player.playerId || ""}`;
    previous.number = previous.number || `${player.number || ""}`;
    previous.position = previous.position || player.position || "";
    previous.started = previous.started || player.started === true;

    Object.keys(previous.batting).forEach((key) => {
      previous.batting[key] += player.batting[key] || 0;
    });
    Object.keys(previous.pitching).forEach((key) => {
      previous.pitching[key] += player.pitching[key] || 0;
    });

    merged.set(bucketKey, previous);
  });

  return Array.from(merged.values());
}

function buildKboFantasyBreakdown(entry) {
  const details = [];
  let total = 0;
  const add = (label, count, pointsPerUnit, formatter = null) => {
    if (!count) return;
    const subtotal = roundFantasyPoints(count * pointsPerUnit);
    total += subtotal;
    const detail = formatter ? formatter(count) : `${count}`;
    details.push({ label, detail, points: subtotal });
  };

  add("Home Run", entry.batting.homeRuns, 5);
  add("Triple", entry.batting.triples, 3);
  add("Double", entry.batting.doubles, 2);
  add("Single", entry.batting.singles, 1);
  add("RBI", entry.batting.rbi, 1);
  add("Run Scored", entry.batting.runs, 1);
  add("Walk", entry.batting.walks, 0.5);
  add("Hit by Pitch", entry.batting.hitByPitch, 0.5);
  add("Stolen Base", entry.batting.stolenBases, 2);
  add("Strikeout", entry.batting.strikeouts, -0.5);

  add(
    "Inning Pitched",
    entry.pitching.inningsPitched,
    2,
    (count) => `${count.toFixed(1)} IP`,
  );
  add("Pitching Strikeout", entry.pitching.strikeouts, 1);
  add("Win", entry.pitching.wins, 5);
  add("Save", entry.pitching.saves, 5);
  add("Earned Run", entry.pitching.earnedRuns, -2);
  add("Pitching Walk", entry.pitching.walks, -0.5);

  return {
    points: roundFantasyPoints(total),
    details,
  };
}

function refreshKboFantasyAnnotationsOnDetail(detail) {
  if (!detail || typeof detail !== "object") return detail;

  const pitching = detail.pitching && typeof detail.pitching === "object" ?
    detail.pitching :
    {};
  const homePitching = pitching.home && typeof pitching.home === "object" ?
    pitching.home :
    {};
  const awayPitching = pitching.away && typeof pitching.away === "object" ?
    pitching.away :
    {};
  const winnerNames = new Set();
  const saveNames = new Set();
  const addWinner = (name) => {
    const normalized = normalizeText(normalizeKboPlayerName(name));
    if (normalized) winnerNames.add(normalized);
  };
  const addSaver = (name) => {
    const normalized = normalizeText(normalizeKboPlayerName(name));
    if (normalized) saveNames.add(normalized);
  };

  const homeResult = firstText(homePitching.result).toLowerCase();
  const awayResult = firstText(awayPitching.result).toLowerCase();
  if (homeResult.includes("승") || homeResult.includes("win")) {
    addWinner(homePitching.name);
  }
  if (awayResult.includes("승") || awayResult.includes("win")) {
    addWinner(awayPitching.name);
  }
  addSaver(homePitching.saveName);
  addSaver(awayPitching.saveName);

  const matchData =
    detail.match && typeof detail.match === "object" ? detail.match : {};
  const homeTeam = normalizeKboTeamName(firstText(matchData.home));
  const awayTeam = normalizeKboTeamName(firstText(matchData.away));
  const originalPlayerStats = Array.isArray(detail.playerStats) ?
    detail.playerStats :
    [];
  if (!originalPlayerStats.length) return detail;

  const updatedPlayerStats = originalPlayerStats.map((raw) => {
    const player =
      raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
    const normalizedName = normalizeText(normalizeKboPlayerName(player.name));
    const pitchingStats =
      player.pitching && typeof player.pitching === "object" ?
        player.pitching :
        {};
    const nextPitching = {
      inningsPitched: Number(pitchingStats.inningsPitched) || 0,
      strikeouts: Number(pitchingStats.strikeouts) || 0,
      wins:
        Number(pitchingStats.wins) > 0 || winnerNames.has(normalizedName) ? 1 : 0,
      losses: Number(pitchingStats.losses) || 0,
      saves:
        Number(pitchingStats.saves) > 0 || saveNames.has(normalizedName) ? 1 : 0,
      earnedRuns: Number(pitchingStats.earnedRuns) || 0,
      walks: Number(pitchingStats.walks) || 0,
    };
    const nextPlayer = {
      ...player,
      pitching: nextPitching,
    };
    return {
      ...nextPlayer,
      fantasy: buildKboFantasyBreakdown(nextPlayer),
    };
  });

  const homeWinner = updatedPlayerStats.find((player) => {
    return (
      normalizeKboTeamName(firstText(player.team)) === homeTeam &&
      Number(player.pitching && player.pitching.wins) > 0
    );
  });
  const awayWinner = updatedPlayerStats.find((player) => {
    return (
      normalizeKboTeamName(firstText(player.team)) === awayTeam &&
      Number(player.pitching && player.pitching.wins) > 0
    );
  });
  const homeLoser = updatedPlayerStats.find((player) => {
    return (
      normalizeKboTeamName(firstText(player.team)) === homeTeam &&
      Number(player.pitching && player.pitching.losses) > 0
    );
  });
  const awayLoser = updatedPlayerStats.find((player) => {
    return (
      normalizeKboTeamName(firstText(player.team)) === awayTeam &&
      Number(player.pitching && player.pitching.losses) > 0
    );
  });
  const homeSaver = updatedPlayerStats.find((player) => {
    return (
      normalizeKboTeamName(firstText(player.team)) === homeTeam &&
      Number(player.pitching && player.pitching.saves) > 0
    );
  });
  const awaySaver = updatedPlayerStats.find((player) => {
    return (
      normalizeKboTeamName(firstText(player.team)) === awayTeam &&
      Number(player.pitching && player.pitching.saves) > 0
    );
  });

  const homePitchingSummary = {
    ...homePitching,
    name:
      firstText(homeWinner && homeWinner.name) ||
      firstText(homeLoser && homeLoser.name) ||
      firstText(homePitching.name),
    result:
      firstText(homePitching.result) ||
      (homeWinner ? "승" : "") ||
      (homeLoser ? "패" : ""),
    saveName:
      firstText(homePitching.saveName) || firstText(homeSaver && homeSaver.name),
  };
  const awayPitchingSummary = {
    ...awayPitching,
    name:
      firstText(awayWinner && awayWinner.name) ||
      firstText(awayLoser && awayLoser.name) ||
      firstText(awayPitching.name),
    result:
      firstText(awayPitching.result) ||
      (awayWinner ? "승" : "") ||
      (awayLoser ? "패" : ""),
    saveName:
      firstText(awayPitching.saveName) || firstText(awaySaver && awaySaver.name),
  };

  return {
    ...detail,
    pitching: {
      home: homePitchingSummary,
      away: awayPitchingSummary,
    },
    playerStats: updatedPlayerStats,
  };
}

function normalizeKboSubstitutionNames(match) {
  const byTeam = new Map();
  const add = (teamName, rawName) => {
    const team = normalizeKboTeamName(teamName);
    const name = normalizeText(normalizeKboPlayerName(rawName));
    if (!team || !name) return;
    if (!byTeam.has(team)) byTeam.set(team, new Set());
    byTeam.get(team).add(name);
  };

  collectDsgValues(match, "event").forEach((event) => {
    const typeText = normalizeText(
      [
        firstText(event.type, event.event_type),
        firstText(event.detail, event.event_detail, event.description),
      ].filter(Boolean).join(" "),
    );
    const isSubstitution =
      typeText.includes("subst") ||
      typeText.includes("substitution") ||
      typeText.includes("change") ||
      typeText.includes("switch") ||
      typeText.includes("replace") ||
      typeText.includes("교체");
    if (!isSubstitution) return;

    const teamName = readKboDetailTeamName(event, match);
    add(teamName, readKboPersonName(event));
    add(
      teamName,
      readKboPersonName((event && event.assist) || {}),
    );
    add(
      teamName,
      firstText(
        event.player_out_name,
        event.replaced_player_name,
        event.out_player_name,
      ),
    );
    add(
      teamName,
      firstText(
        event.player_in_name,
        event.substitute_player_name,
        event.in_player_name,
      ),
    );
    [
      ...collectDsgValues(event, "player"),
      ...collectDsgValues(event, "person"),
      ...collectDsgValues(event, "people"),
    ].forEach((row) => {
      add(teamName, readKboPersonName(row));
    });
  });

  return byTeam;
}

function kboPlayerRecordedAppearance(player) {
  if (!player || typeof player !== "object") return false;
  const batting = player.batting || {};
  const pitching = player.pitching || {};
  return (
    Object.values(batting).some((value) => Number(value) > 0) ||
    Object.values(pitching).some((value) => Number(value) > 0)
  );
}

function kboPositionNeedsFallback(position) {
  const raw = firstText(position).toUpperCase();
  return !raw || /^\d+$/.test(raw);
}

function kboBenchCanReplaceStarter(benchPosition, starterPosition) {
  const bench = normalizeKboPosition(benchPosition);
  const starter = normalizeKboPosition(starterPosition);
  if (!bench || !starter) return false;
  if (bench === starter) return true;
  if (bench === "IF") return ["1B", "2B", "3B", "SS", "IF"].includes(starter);
  if (bench === "OF") return ["LF", "CF", "RF", "OF"].includes(starter);
  return false;
}

function annotateKboLineupSubstitutions(lineups, playerStats, match) {
  const substitutionNamesByTeam = normalizeKboSubstitutionNames(match);
  const benchAppearanceNamesByTeam = new Map();
  const playerStatsByTeamAndName = new Map();

  asArray(playerStats).forEach((player) => {
    if (!player || typeof player !== "object") return;
    const team = normalizeKboTeamName(firstText(player.team));
    const name = normalizeText(player.name);
    const position = normalizeKboPosition(player.position);
    if (team && name && position) {
      playerStatsByTeamAndName.set(`${team}|${name}`, {
        position,
        started: player.started === true,
      });
    }

    if (player.started === true) return;
    if (!team || !name) return;
    if (!kboPlayerRecordedAppearance(player)) return;
    if (!benchAppearanceNamesByTeam.has(team)) {
      benchAppearanceNamesByTeam.set(team, new Set());
    }
    benchAppearanceNamesByTeam.get(team).add(name);
  });

  return asArray(lineups).map((lineup) => {
    const teamName = normalizeKboTeamName(firstText(lineup && lineup.team));
    const substitutionNames = substitutionNamesByTeam.get(teamName) || new Set();
    const benchAppearanceNames =
      benchAppearanceNamesByTeam.get(teamName) || new Set();
    const resolvePlayerPosition = (player) => {
      const rawPosition = firstText(player && player.position);
      if (!kboPositionNeedsFallback(rawPosition)) {
        return normalizeKboPosition(rawPosition);
      }
      const nameKey = normalizeText(firstText(player && player.name));
      const stat = playerStatsByTeamAndName.get(`${teamName}|${nameKey}`);
      return firstText(stat && stat.position);
    };
    const isSubstituted = (player, { includeBenchAppearance = false } = {}) => {
      const nameKey = normalizeText(firstText(player && player.name));
      if (!nameKey) return false;
      if (substitutionNames.has(nameKey)) return true;
      return includeBenchAppearance && benchAppearanceNames.has(nameKey);
    };

    const substitutes = asArray(lineup && lineup.substitutes).map((player) => ({
      ...player,
      position: resolvePlayerPosition(player),
      substituted: isSubstituted(player, { includeBenchAppearance: true }),
    }));
    const substitutedBenchPlayers = substitutes.filter(
      (player) => player.substituted === true,
    );
    const assignedBenchNames = new Set();
    const inferStarterSubstituted = (player) => {
      if (isSubstituted(player)) return true;
      const starterPosition = resolvePlayerPosition(player);
      for (const benchPlayer of substitutedBenchPlayers) {
        const benchNameKey = normalizeText(firstText(benchPlayer.name));
        if (!benchNameKey || assignedBenchNames.has(benchNameKey)) continue;
        if (!kboBenchCanReplaceStarter(benchPlayer.position, starterPosition)) {
          continue;
        }
        assignedBenchNames.add(benchNameKey);
        return true;
      }
      return false;
    };
    const starterPitcherSubstituted =
      substitutionNames.has(normalizeText(firstText(lineup && lineup.starterPitcher))) ||
      substitutedBenchPlayers.some((player) => normalizeKboPosition(player.position) === "P");

    return {
      ...lineup,
      players: asArray(lineup && lineup.players).map((player) => ({
        ...player,
        position: resolvePlayerPosition(player),
        substituted: inferStarterSubstituted(player),
      })),
      starterPitcherSubstituted,
      substitutes,
    };
  });
}

function normalizeKboPlayerStats(
  match,
  rosterLookup = buildKboRosterLookup([]),
  lineupsOverride = null,
) {
  const lineups = asArray(lineupsOverride).length
    ? asArray(lineupsOverride)
    : normalizeKboLineups(match, rosterLookup);
  const decisions = normalizeKboPitchingDecisionNames(match);
  const lineupStarters = new Map();

  lineups.forEach((lineup) => {
    lineup.players.forEach((player) => {
      const roster =
        rosterLookup.byTeamNumber.get(
          `${normalizeText(lineup.team)}:${firstText(player.number)}`,
        ) || rosterLookup.byName.get(normalizeText(player.name));
      const identity = buildKboPlayerIdentity({
        teamId: lineup.teamId,
        teamName: lineup.team,
        playerId: roster && roster.playerId,
        number: firstText(player.number, roster && roster.number),
        name: player.name,
      });
      lineupStarters.set(identity, {
        teamId: firstText(lineup.teamId, roster && roster.teamId),
        team: lineup.team,
        playerId: firstText(roster && roster.playerId),
        name: player.name,
        number: firstText(player.number, roster && roster.number),
        position: normalizeKboPosition(
          firstText(player.position, roster && roster.position),
        ),
        started: true,
      });
    });
    if (lineup.starterPitcher) {
      const roster = rosterLookup.byName.get(
        normalizeText(lineup.starterPitcher),
      );
      const identity = buildKboPlayerIdentity({
        teamId: lineup.teamId,
        teamName: lineup.team,
        playerId: roster && roster.playerId,
        number: firstText(roster && roster.number),
        name: lineup.starterPitcher,
      });
      lineupStarters.set(identity, {
        teamId: firstText(lineup.teamId, roster && roster.teamId),
        team: lineup.team,
        playerId: firstText(roster && roster.playerId),
        name: lineup.starterPitcher,
        number: firstText(roster && roster.number),
        position: "P",
        started: true,
      });
    }
  });

  const statRows = collectKboPlayerStatRows(match);

  const playerMap = new Map();
  const upsert = ({
    teamId,
    teamName,
    playerId,
    name,
    number,
    position,
    batting,
    pitching,
    started,
  }) => {
    const identity = buildKboPlayerIdentity({
      teamId,
      teamName,
      playerId,
      number,
      name,
    });
    const previous = playerMap.get(identity) || {
      teamId: `${teamId || ""}`,
      team: teamName,
      playerId: `${playerId || ""}`,
      name,
      number: `${number || ""}`,
      position: position || "",
      started: false,
      batting: {
        singles: 0,
        doubles: 0,
        triples: 0,
        homeRuns: 0,
        rbi: 0,
        runs: 0,
        walks: 0,
        hitByPitch: 0,
        stolenBases: 0,
        strikeouts: 0,
      },
      pitching: {
        inningsPitched: 0,
        strikeouts: 0,
        wins: 0,
        losses: 0,
        saves: 0,
        earnedRuns: 0,
        walks: 0,
      },
    };
    previous.teamId = previous.teamId || `${teamId || ""}`;
    previous.team = previous.team || teamName;
    previous.playerId = previous.playerId || `${playerId || ""}`;
    previous.number = previous.number || `${number || ""}`;
    previous.position = previous.position || position || "";
    previous.started = previous.started || started;
    Object.keys(previous.batting).forEach((key) => {
      previous.batting[key] += batting[key] || 0;
    });
    Object.keys(previous.pitching).forEach((key) => {
      previous.pitching[key] += pitching[key] || 0;
    });
    playerMap.set(identity, previous);
  };

  statRows.forEach((row) => {
    const teamId = firstText(row.team_id, row.competitor_id, row.club_id);
    const teamName = readKboDetailTeamName(row, match);
    const roster = findKboRosterPlayer(row, rosterLookup, teamName, teamId);
    const name = readKboPersonName(roster || row) || readKboPersonName(row);
    if (!name) return;

    const number = firstText(
      readKboUniformNumber(row),
      roster && roster.number,
    );
    const playerId = firstText(readKboPersonId(row), roster && roster.playerId);
    const identity = buildKboPlayerIdentity({
      teamId,
      teamName,
      playerId,
      number,
      name,
    });
    const starterEntry =
      lineupStarters.get(identity) ||
      lineupStarters.get(
        buildKboPlayerIdentity({
          teamId,
          teamName,
          number,
          name,
        }),
      ) ||
      lineupStarters.get(
        buildKboPlayerIdentity({
          teamId,
          teamName,
          name,
        }),
      ) ||
      null;
    const position = normalizeKboPosition(
      firstText(readKboPosition(row), roster && roster.position),
    );
    const rosterPosition = normalizeKboPosition(
      firstText(roster && roster.position),
    );

    const inningsPitched = firstDsgInningsPitched(row, [
      "innings_pitched",
      "inning_pitched",
      "ip",
    ]);
    const starterPosition = normalizeKboPosition(
      firstText(starterEntry && starterEntry.position),
    );
    const pitcherLike =
      position === "P" ||
      rosterPosition === "P" ||
      starterPosition === "P" ||
      inningsPitched > 0;
    const hits = pitcherLike ?
      0 :
      firstDsgNumericStat(row, ["hits", "hit", "h", "base_hits"]);
    const doubles = pitcherLike ?
      0 :
      firstDsgNumericStat(row, ["double", "doubles", "2b"]);
    const triples = pitcherLike ?
      0 :
      firstDsgNumericStat(row, ["triple", "triples", "3b"]);
    const homeRuns = pitcherLike ?
      0 :
      firstDsgNumericStat(row, [
        "home_run",
        "home_runs",
        "homerun",
        "homeruns",
        "hr",
      ]);
    const explicitSingles = pitcherLike ?
      0 :
      firstDsgNumericStat(row, [
        "single",
        "singles",
        "1b",
      ]);
    const singles =
      explicitSingles > 0
        ? explicitSingles
        : Math.max(0, hits - doubles - triples - homeRuns);
    const rbi = pitcherLike ?
      0 :
      firstDsgNumericStat(row, [
        "rbi",
        "runs_batted_in",
        "run_batted_in",
      ]);
    const runs = pitcherLike ?
      0 :
      firstDsgNumericStat(row, [
        "runs",
        "run",
        "r",
        "total_runs",
        "total_run",
        "runs_scored",
        "run_scored",
        "run_score",
        "scored_run",
        "scored_runs",
        "score_run",
        "runscore",
      ]);
    const battingWalks = pitcherLike ?
      0 :
      firstDsgNumericStat(row, [
        "walk",
        "walks",
        "bb",
        "base_on_balls",
        "bases_on_balls",
      ]);
    const hitByPitch = pitcherLike ?
      0 :
      firstDsgNumericStat(row, ["hbp", "hit_by_pitch"]);
    const stolenBases = pitcherLike ?
      0 :
      firstDsgNumericStat(row, [
        "stolen_base",
        "stolen_bases",
        "sb",
      ]);
    const battingStrikeouts = pitcherLike ?
      0 :
      firstDsgNumericStat(row, [
        "strikeout",
        "strikeouts",
        "so",
        "k",
      ]);
    const explicitPitchingStrikeouts = firstDsgNumericStat(row, [
      "pitching_strikeouts",
      "strikeouts_pitched",
      "pitcher_strikeouts",
      "strikeout_pitching",
    ]);
    const pitchingStrikeouts =
      explicitPitchingStrikeouts > 0 || !pitcherLike ?
        explicitPitchingStrikeouts :
        firstDsgNumericStat(row, [
          "strikeouts",
          "so",
          "k",
        ]);
    const earnedRuns = firstDsgNumericStat(row, [
      "earned_run",
      "earned_runs",
      "er",
    ]);
    const explicitPitchingWalks = firstDsgNumericStat(row, [
      "pitching_walks",
      "walks_allowed",
      "base_on_balls_allowed",
    ]);
    const pitchingWalks =
      explicitPitchingWalks > 0 || !pitcherLike ?
        explicitPitchingWalks :
        firstDsgNumericStat(row, [
          "base_on_balls",
          "bb",
          "walks",
        ]);
    const explicitPitchingWins = firstDsgNumericStat(row, [
      "wins",
      "win",
      "games_won",
      "winning_pitcher",
    ]);
    const explicitPitchingLosses = firstDsgNumericStat(row, [
      "losses",
      "loss",
      "games_lost",
      "losing_pitcher",
    ]);
    const explicitPitchingSaves = firstDsgNumericStat(row, [
      "saves",
      "save",
      "sv",
      "save_pitcher",
      "saving_pitcher",
    ]);

    const wins =
      explicitPitchingWins > 0 ||
      decisions.winnerNames.has(normalizeText(name)) ?
        1 :
        0;
    const losses = explicitPitchingLosses > 0 ? 1 : 0;
    const saves =
      explicitPitchingSaves > 0 ||
      decisions.saveNames.has(normalizeText(name)) ?
        1 :
        0;
    const started = (starterEntry || {}).started === true || isKboStarter(row);

    const batting = {
      singles,
      doubles,
      triples,
      homeRuns,
      rbi,
      runs,
      walks: battingWalks,
      hitByPitch,
      stolenBases,
      strikeouts: battingStrikeouts,
    };
    const pitching = {
      inningsPitched,
      strikeouts: pitchingStrikeouts,
      wins,
      losses,
      saves,
      earnedRuns,
      walks: pitchingWalks,
    };

    const hasStats =
      Object.values(batting).some((value) => value > 0) ||
      Object.values(pitching).some((value) => value > 0);
    if (!hasStats && !started) return;

    upsert({
      teamId: firstText(teamId, starterEntry && starterEntry.teamId),
      teamName: teamName || (starterEntry && starterEntry.team) || "",
      playerId: firstText(playerId, starterEntry && starterEntry.playerId),
      name,
      number: firstText(number, starterEntry && starterEntry.number),
      position: position || (starterEntry && starterEntry.position) || "",
      batting,
      pitching,
      started,
    });
  });

  lineupStarters.forEach((starter, identity) => {
    if (playerMap.has(identity)) return;
    upsert({
      teamId: starter.teamId,
      teamName: starter.team,
      playerId: starter.playerId,
      name: starter.name,
      number: starter.number,
      position: starter.position,
      batting: {
        singles: 0,
        doubles: 0,
        triples: 0,
        homeRuns: 0,
        rbi: 0,
        runs: 0,
        walks: 0,
        hitByPitch: 0,
        stolenBases: 0,
        strikeouts: 0,
      },
      pitching: {
        inningsPitched: 0,
        strikeouts: 0,
        wins: decisions.winnerNames.has(normalizeText(starter.name)) ? 1 : 0,
        losses: 0,
        saves: decisions.saveNames.has(normalizeText(starter.name)) ? 1 : 0,
        earnedRuns: 0,
        walks: 0,
      },
      started: starter.started,
    });
  });

  return mergeKboPlayerEntries(Array.from(playerMap.values()))
    .map((player) => ({
      ...player,
      fantasy: buildKboFantasyBreakdown(player),
    }))
    .sort((a, b) => {
      const teamCompare = a.team.localeCompare(b.team, "ko");
      if (teamCompare !== 0) return teamCompare;
      const leftNumber = toInt(a.number) > 0 ? toInt(a.number) : 999;
      const rightNumber = toInt(b.number) > 0 ? toInt(b.number) : 999;
      if (leftNumber !== rightNumber) return leftNumber - rightNumber;
      return a.name.localeCompare(b.name, "ko");
    });
}

/**
 * Loads detail data for one KBO match.
 * @param {string|number} matchId DSG match id
 * @return {Promise<Object>} normalized detail data
 */
async function fetchKboMatchDetails(matchId, options = {}) {
  const fantasyRound =
    Number.parseInt(`${options && options.fantasyRound || "0"}`, 10) || 0;
  const preferFreshLiveData = options && options.preferFreshLiveData === true;
  if (fantasyRound > 0) {
    const frozenSnapshot =
      (await loadFrozenKboCancelledMatches()).byId.get(`${matchId}`) || null;
    if (
      frozenSnapshot &&
      frozenSnapshot.originalRound === fantasyRound &&
      frozenSnapshot.detail
    ) {
      const refreshedFrozenDetail = refreshKboFantasyAnnotationsOnDetail(
        frozenSnapshot.detail,
      );
      return {
        ...refreshedFrozenDetail,
        generatedAt: new Date().toISOString(),
      };
    }
  }

  const cacheKey = `${matchId}`;
  const cached = kboMatchDetailsCache.get(cacheKey);
  const cacheTtlMs =
    preferFreshLiveData ? KBO_LIVE_UPDATES_TTL_MS : CACHE_TTL_MS;
  if (isCacheFreshFor(cached, cacheTtlMs)) {
    const shouldRefresh = await shouldRefreshCachedKboMatchDetail(
      matchId,
      cached.data,
      cached.createdAt,
    );
    if (!shouldRefresh) {
      const matchData = (cached.data || {}).match || {};
      const liveUpdates = await fetchKboLiveUpdatesOptional();
      const patch = liveUpdates.byId.get(cacheKey);
      const officialScoreboardMatches = matchData.date ?
        await fetchKboOfficialScoreboardDay(matchData.date) : [];
      const officialLiveInningLabel = buildKboOfficialScoreboardMap(
        officialScoreboardMatches,
      ).get(
        kboOfficialScoreboardMatchKey(matchData.away, matchData.home),
      ) || "";
      if (!patch && !officialLiveInningLabel) return cached.data;
      const mergedMatch = mergeKboMatchUpdate(matchData, patch);
      return {
        ...cached.data,
        generatedAt: new Date().toISOString(),
        match: {
          ...mergedMatch,
          liveInningLabel:
            officialLiveInningLabel ||
            mergedMatch.liveInningLabel ||
            matchData.liveInningLabel ||
            "",
        },
      };
    }
    kboMatchDetailsCache.delete(cacheKey);
    kboPeopleDetailCache.clear();
  }

  const data = await dsgBaseballGet("get_matches", {
    type: "match",
    id: matchId,
    detailed: "yes",
  });
  const rootMatch = ((data || {}).datasportsgroup || {}).match;
  const match = extractKboMatches(data)[0] || asArray(rootMatch)[0] || {};
  const normalizedMatch = normalizeKboMatches([match])[0] || {};
  const seasonMatches = await fetchKboSeasonDetailedMatches();
  const seasonMatch = seasonMatches.find((row) => {
    return `${firstText(row.match_id, row.id)}` === `${matchId}`;
  }) || null;
  const dayMatches = normalizedMatch.date
    ? await fetchKboMatchesDay(normalizedMatch.date)
    : [];
  const dayMatch = dayMatches.find((row) => {
    return `${firstText(row.match_id, row.id)}` === `${matchId}`;
  }) || null;
  const officialScoreboardMatches = normalizedMatch.date ?
    await fetchKboOfficialScoreboardDay(normalizedMatch.date) : [];
  const officialLiveInningByTeams = buildKboOfficialScoreboardMap(
    officialScoreboardMatches,
  );
  const officialLiveInningLabel = officialLiveInningByTeams.get(
    kboOfficialScoreboardMatchKey(
      normalizedMatch.away || normalizeKboTeamName(match.team_b_name),
      normalizedMatch.home || normalizeKboTeamName(match.team_a_name),
    ),
  ) || "";
  const squadResponses = await Promise.all(
    [normalizedMatch.homeTeamId, normalizedMatch.awayTeamId]
      .filter(Boolean)
      .map(fetchKboSquad),
  );
  const rosterLookup = buildKboRosterLookup(squadResponses);
  const primaryLineups = normalizeKboLineups(match, rosterLookup);
  const seasonLineups = seasonMatch ?
    normalizeKboLineups(seasonMatch, rosterLookup) : [];
  const dayLineups = dayMatch ? normalizeKboLineups(dayMatch, rosterLookup) : [];
  const lineups = mergeKboLineupSources(
    mergeKboLineupSources(primaryLineups, seasonLineups),
    dayLineups,
  );
  const pitching = mergeKboPitchingSources(match, seasonMatch, dayMatch);
  const playerStats = normalizeKboPlayerStats(match, rosterLookup, lineups);
  const annotatedLineups = annotateKboLineupSubstitutions(
    lineups,
    playerStats,
    match,
  );
  const detail = {
    generatedAt: new Date().toISOString(),
    match: {
      ...normalizedMatch,
      liveInningLabel:
        officialLiveInningLabel ||
        extractKboLiveInningLabel(match) ||
        extractKboLiveInningLabel(dayMatch) ||
        extractKboLiveInningLabel(seasonMatch) ||
        normalizedMatch.liveInningLabel ||
        "",
    },
    innings: normalizeKboInnings(match),
    pitching,
    lineups: annotatedLineups,
    playerStats,
    homeRunEvents: extractKboHomeRunEvents(match),
  };
  const refreshedDetail = refreshKboFantasyAnnotationsOnDetail(detail);

  kboMatchDetailsCache.set(cacheKey, {
    createdAt: Date.now(),
    data: refreshedDetail,
  });
  const liveUpdates = await fetchKboLiveUpdatesOptional();
  const patch = liveUpdates.byId.get(cacheKey);
  if (!patch) return refreshedDetail;
  return {
    ...refreshedDetail,
    generatedAt: new Date().toISOString(),
    match: mergeKboMatchUpdate(refreshedDetail.match || {}, patch),
  };
}

/**
 * Loads the KBO season, standings and schedule bundle.
 * @return {Promise<Object>} normalized KBO data
 */
async function fetchKboLeagueData() {
  if (isCacheFresh(kboLeagueCache)) {
    let frozenCancelledMatches = await loadFrozenKboCancelledMatches();
    const missingCancelledMatches = (kboLeagueCache.data.matches || []).filter(
      (match) =>
        isKboCancelledStatus(match && match.status) &&
        !frozenCancelledMatches.byId.has(`${match.id}`),
    );
    if (missingCancelledMatches.length) {
      await Promise.all(
        missingCancelledMatches.map((match) =>
          captureFrozenKboCancelledMatchSnapshot(match),
        ),
      );
      frozenCancelledMatches = await loadFrozenKboCancelledMatches();
    }
    const liveUpdates = await fetchKboLiveUpdatesOptional();
    const todayKey = kstDateKeyFromMs(Date.now());
    const [todayMatches, officialScoreboardMatches] = await Promise.all([
      fetchKboMatchesDay(todayKey),
      fetchKboOfficialScoreboardDay(todayKey),
    ]);
    const liveInningById = buildKboLiveInningMap(todayMatches);
    const officialLiveInningByTeams = buildKboOfficialScoreboardMap(
      officialScoreboardMatches,
    );
    return {
      ...kboLeagueCache.data,
      generatedAt: new Date().toISOString(),
      fantasyExcludedMatches: frozenCancelledMatches.list.map((entry) => ({
        matchId: entry.matchId,
        originalRound: entry.originalRound,
        originalDate: entry.originalDate,
        home: entry.home,
        away: entry.away,
        status: entry.status,
      })),
      matches: (kboLeagueCache.data.matches || []).map((match) => {
        const patch = liveUpdates.byId.get(`${match.id}`);
        const merged = patch ? mergeKboMatchUpdate(match, patch) : match;
        return {
          ...merged,
          liveInningLabel:
            officialLiveInningByTeams.get(
              kboOfficialScoreboardMatchKey(merged.away, merged.home),
            ) ||
            liveInningById.get(`${merged.id}`) || merged.liveInningLabel || "",
        };
      }),
    };
  }

  const [seasonsData, roundsData, tablesData, matchesData] = await Promise.all([
    dsgBaseballGet("get_seasons", { comp_id: KBO_COMPETITION_ID }),
    dsgBaseballGet("get_rounds", { season_id: KBO_SEASON_ID }),
    dsgBaseballGet("get_tables", { type: "season", id: KBO_SEASON_ID }),
    dsgBaseballGet("get_matches", { type: "season", id: KBO_SEASON_ID }),
  ]);

  const previousData =
    kboLeagueCache && kboLeagueCache.data ? kboLeagueCache.data : null;
  const parsedStandings = normalizeKboStandings(extractKboTableLoose(tablesData));
  let parsedMatches = normalizeKboMatches(extractKboMatchesLoose(matchesData));
  if (!parsedMatches.length) {
    parsedMatches = normalizeKboMatches(await fetchKboSeasonDetailedMatches());
  }
  const standings =
    parsedStandings.length ? parsedStandings : asArray(previousData && previousData.standings);
  const matches =
    parsedMatches.length ? parsedMatches : asArray(previousData && previousData.matches);
  if (!parsedStandings.length && standings.length) {
    console.warn("KBO standings parse returned empty rows; preserving previous standings cache");
  }
  if (!parsedMatches.length && matches.length) {
    console.warn("KBO matches parse returned empty rows; preserving previous matches cache");
  }

  const data = {
    season: SEASON_YEAR,
    competitionId: KBO_COMPETITION_ID,
    seasonId: KBO_SEASON_ID,
    generatedAt: new Date().toISOString(),
    seasonInfo: extractKboSeason(seasonsData),
    rounds: extractKboRounds(roundsData),
    standings,
    matches,
  };

  const cancelledMatches = data.matches.filter((match) =>
    isKboCancelledStatus(match && match.status),
  );
  if (cancelledMatches.length) {
    await Promise.all(
      cancelledMatches.map((match) => captureFrozenKboCancelledMatchSnapshot(match)),
    );
  }
  const frozenCancelledMatches = await loadFrozenKboCancelledMatches();

  kboLeagueCache = { createdAt: Date.now(), data };
  const liveUpdates = await fetchKboLiveUpdatesOptional();
  const todayKey = kstDateKeyFromMs(Date.now());
  const [todayMatches, officialScoreboardMatches] = await Promise.all([
    fetchKboMatchesDay(todayKey),
    fetchKboOfficialScoreboardDay(todayKey),
  ]);
  const liveInningById = buildKboLiveInningMap(todayMatches);
  const officialLiveInningByTeams = buildKboOfficialScoreboardMap(
    officialScoreboardMatches,
  );
  return {
    ...data,
    generatedAt: new Date().toISOString(),
    fantasyExcludedMatches: frozenCancelledMatches.list.map((entry) => ({
      matchId: entry.matchId,
      originalRound: entry.originalRound,
      originalDate: entry.originalDate,
      home: entry.home,
      away: entry.away,
      status: entry.status,
    })),
    matches: data.matches.map((match) => {
      const patch = liveUpdates.byId.get(`${match.id}`);
      const merged = patch ? mergeKboMatchUpdate(match, patch) : match;
      return {
        ...merged,
        liveInningLabel:
          officialLiveInningByTeams.get(
            kboOfficialScoreboardMatchKey(merged.away, merged.home),
          ) ||
          liveInningById.get(`${merged.id}`) || merged.liveInningLabel || "",
      };
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
    return foundById
      ? foundById.team
      : {
          id: teamId,
          name: `${teamId}`,
        };
  }

  const target = normalizeText(teamQuery);
  const foundByName = teams.find((entry) => {
    const team = entry.team || {};
    return (
      normalizeText(team.name) === target ||
      normalizeText(team.name).includes(target) ||
      target.includes(normalizeText(team.name))
    );
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

  teamStatsCache.set(cacheKey, { createdAt: Date.now(), data });
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

  const firestoreCached = await readFixtureDetailsFirestoreCache(cacheKey);
  if (firestoreCached && shouldReuseFirestoreFixtureDetails(firestoreCached)) {
    fixtureDetailsCache.set(cacheKey, {
      createdAt: Date.now(),
      data: firestoreCached,
    });
    return firestoreCached;
  }

  const fixtureData = await apiSportsGet("/fixtures", { id: fixtureId });
  let [statisticsData, eventsData, lineupsData, playersData] =
    await Promise.all([
      apiSportsGetOptional("/fixtures/statistics", { fixture: fixtureId }),
      apiSportsGetOptional("/fixtures/events", { fixture: fixtureId }),
      apiSportsGetOptional("/fixtures/lineups", { fixture: fixtureId }),
      apiSportsGetOptional("/fixtures/players", { fixture: fixtureId }),
    ]);

  const fixture = (fixtureData.response || [])[0] || null;
  const fixtureStatus =
    fixture && fixture.fixture && fixture.fixture.status
      ? `${fixture.fixture.status.short || ""}`.trim().toUpperCase()
      : "";
  const isFinalFixture = ["FT", "AET", "PEN"].includes(fixtureStatus);

  if (isFinalFixture) {
    if (!hasOptionalSectionData(eventsData)) {
      eventsData = await refetchOptionalSection("/fixtures/events", {
        fixture: fixtureId,
      });
    }
    if (!hasOptionalSectionData(lineupsData)) {
      lineupsData = await refetchOptionalSection("/fixtures/lineups", {
        fixture: fixtureId,
      });
    }
    if (!hasOptionalSectionData(playersData)) {
      playersData = await refetchOptionalSection("/fixtures/players", {
        fixture: fixtureId,
      });
    }
    if (!hasOptionalSectionData(eventsData)) {
      eventsData = await refetchOptionalSection("/fixtures/events", {
        fixture: fixtureId,
      }, 4);
    }
    if (!hasOptionalSectionData(statisticsData)) {
      statisticsData = await refetchOptionalSection("/fixtures/statistics", {
        fixture: fixtureId,
      }, 4);
    }
  }

  const data = {
    season: SEASON_YEAR,
    leagueId: K_LEAGUE_1_ID,
    fixtureId,
    generatedAt: new Date().toISOString(),
    fixture,
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

  const hasCriticalDetail = fixtureDetailsHasCriticalData(data);
  const hasRenderableEvents = fixtureDetailsHasRenderableEventData(data);
  const isReusableFinalDetail =
    !isFinalFixture || (hasCriticalDetail && hasRenderableEvents);

  if (isReusableFinalDetail) {
    fixtureDetailsCache.set(cacheKey, { createdAt: Date.now(), data });
  } else {
    fixtureDetailsCache.delete(cacheKey);
  }
  if (isFinalFixture && hasCriticalDetail && hasRenderableEvents) {
    await writeFixtureDetailsFirestoreCache(cacheKey, data);
  }
  return data;
}

exports.getLeagueStandings = onRequest(
  { cors: true, secrets: ["API_SPORTS_KEY"] },
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
    secrets: ["DSG_CLIENT", "DSG_USERNAME", "DSG_PASSWORD", "DSG_AUTHKEY"],
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
    secrets: ["DSG_CLIENT", "DSG_USERNAME", "DSG_PASSWORD", "DSG_AUTHKEY"],
  },
  async (req, res) => {
    try {
      const match = req.query.match;
      const fantasyRound =
        Number.parseInt(`${req.query.round || "0"}`, 10) || 0;
      if (!match) {
        res.status(400).json({
          error: "match query parameter is required",
        });
        return;
      }

      res.json(await fetchKboMatchDetails(match, { fantasyRound }));
    } catch (error) {
      console.error((error.response && error.response.data) || error.message);
      res.status(error.statusCode || 500).json({
        error: "Error fetching KBO match details",
      });
    }
  },
);

exports.getTeamStatistics = onRequest(
  { cors: true, secrets: ["API_SPORTS_KEY"] },
  async (req, res) => {
    try {
      const team = req.query.team;
      if (!team) {
        res.status(400).json({ error: "team query parameter is required" });
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
  { cors: true, secrets: ["API_SPORTS_KEY"] },
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

  const query = await db
    .collection("leagues")
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
        throw new HttpsError("failed-precondition", "League is already full");
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
      transaction.set(
        userRef,
        {
          leagueIds: admin.firestore.FieldValue.arrayUnion(leagueRef.id),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    const rawDraftDate = data.draftDateTime;
    const draftDateTime =
      rawDraftDate && typeof rawDraftDate.toDate === "function"
        ? rawDraftDate.toDate().toISOString()
        : "";

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

  const draftBoard = Array.isArray(request.data && request.data.draftBoard)
    ? request.data.draftBoard
    : [];
  const fantasyTeams = Array.isArray(request.data && request.data.fantasyTeams)
    ? request.data.fantasyTeams
    : [];
  const fantasySchedule = Array.isArray(
    request.data && request.data.fantasySchedule,
  )
    ? request.data.fantasySchedule
    : [];

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

    if (
      data.fantasyReady === true &&
      Array.isArray(data.fantasyTeams) &&
      Array.isArray(data.fantasySchedule)
    ) {
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

async function renameFantasyIdentityForUid(uid, teamName) {
  const normalizedUid = `${uid || ""}`.trim();
  const normalizedTeamName = `${teamName || ""}`.trim().replace(/\s+/g, " ");
  if (!normalizedUid || !normalizedTeamName) {
    return { updatedLeagueCount: 0, updatedTradeRequestCount: 0 };
  }

  const leaguesSnapshot = await db
    .collection("leagues")
    .where("members", "array-contains", normalizedUid)
    .get();
  const tradeRequestsSnapshot = await db
    .collection("tradeRequests")
    .where("participants", "array-contains", normalizedUid)
    .get();

  let updatedLeagueCount = 0;
  let updatedTradeRequestCount = 0;
  const batch = db.batch();

  for (const doc of leaguesSnapshot.docs) {
    const data = doc.data() || {};
    let changed = false;
    const update = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (Array.isArray(data.draftOrder)) {
      const nextDraftOrder = data.draftOrder.map((entry) => {
        const draftEntry = entry && typeof entry === "object" ? entry : {};
        if (`${draftEntry.uid || ""}`.trim() !== normalizedUid) {
          return draftEntry;
        }
        if (`${draftEntry.displayName || ""}`.trim() === normalizedTeamName) {
          return draftEntry;
        }
        changed = true;
        return {
          ...draftEntry,
          displayName: normalizedTeamName,
        };
      });
      if (changed) {
        update.draftOrder = nextDraftOrder;
      }
    }

    if (Array.isArray(data.fantasyTeams)) {
      const nextFantasyTeams = data.fantasyTeams.map((team) => {
        const fantasyTeam = team && typeof team === "object" ? team : {};
        if (`${fantasyTeam.uid || ""}`.trim() !== normalizedUid) {
          return fantasyTeam;
        }
        if (`${fantasyTeam.teamName || ""}`.trim() === normalizedTeamName) {
          return fantasyTeam;
        }
        changed = true;
        return {
          ...fantasyTeam,
          teamName: normalizedTeamName,
        };
      });
      if (changed) {
        update.fantasyTeams = nextFantasyTeams;
      }
    }

    if (Array.isArray(data.fantasySchedule)) {
      let scheduleChanged = false;
      const nextFantasySchedule = data.fantasySchedule.map((matchup) => {
        const scheduleEntry =
          matchup && typeof matchup === "object" ? matchup : {};
        const nextEntry = { ...scheduleEntry };
        if (`${scheduleEntry.homeUid || ""}`.trim() === normalizedUid) {
          if (`${scheduleEntry.homeTeam || ""}`.trim() !== normalizedTeamName) {
            nextEntry.homeTeam = normalizedTeamName;
            scheduleChanged = true;
          }
        }
        if (`${scheduleEntry.awayUid || ""}`.trim() === normalizedUid) {
          if (`${scheduleEntry.awayTeam || ""}`.trim() !== normalizedTeamName) {
            nextEntry.awayTeam = normalizedTeamName;
            scheduleChanged = true;
          }
        }
        return nextEntry;
      });
      if (scheduleChanged) {
        changed = true;
        update.fantasySchedule = nextFantasySchedule;
      }
    }

    if (!changed) continue;
    batch.update(doc.ref, update);
    updatedLeagueCount += 1;
  }

  for (const doc of tradeRequestsSnapshot.docs) {
    const data = doc.data() || {};
    const update = {};
    let changed = false;
    if (`${data.fromUid || ""}`.trim() === normalizedUid) {
      if (`${data.fromTeamName || ""}`.trim() !== normalizedTeamName) {
        update.fromTeamName = normalizedTeamName;
        changed = true;
      }
    }
    if (`${data.toUid || ""}`.trim() === normalizedUid) {
      if (`${data.toTeamName || ""}`.trim() !== normalizedTeamName) {
        update.toTeamName = normalizedTeamName;
        changed = true;
      }
    }
    if (!changed) continue;
    update.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    batch.update(doc.ref, update);
    updatedTradeRequestCount += 1;
  }

  if (updatedLeagueCount > 0 || updatedTradeRequestCount > 0) {
    await batch.commit();
  }

  return { updatedLeagueCount, updatedTradeRequestCount };
}

exports.renameFantasyTeamIdentity = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const teamName = `${(request.data && request.data.teamName) || ""}`
    .trim()
    .replace(/\s+/g, " ");
  if (!teamName) {
    throw new HttpsError("invalid-argument", "teamName is required");
  }

  const { updatedLeagueCount, updatedTradeRequestCount } =
    await renameFantasyIdentityForUid(uid, teamName);

  return {
    teamName,
    updatedLeagueCount,
    updatedTradeRequestCount,
  };
});

exports.syncFantasyIdentityFromUserProfile = onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const uid = `${(event.params && event.params.uid) || ""}`.trim();
    if (!uid) return;

    const before = event.data.before.exists ? event.data.before.data() || {} : {};
    const after = event.data.after.exists ? event.data.after.data() || {} : {};
    if (!event.data.after.exists) return;

    const beforeDisplayName = `${before.displayName || ""}`
      .trim()
      .replace(/\s+/g, " ");
    const afterDisplayName = `${after.displayName || ""}`
      .trim()
      .replace(/\s+/g, " ");
    const afterNormalizedDisplayName =
      `${after.normalizedDisplayName || ""}`.trim().toLowerCase() ||
      normalizeText(afterDisplayName);
    const afterPhotoUrl = `${after.photoUrl || ""}`.trim();

    await db.collection("publicUserProfiles").doc(uid).set(
      {
        uid,
        displayName: afterDisplayName,
        normalizedDisplayName: afterNormalizedDisplayName,
        photoUrl: afterPhotoUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (!afterDisplayName || afterDisplayName === beforeDisplayName) {
      return;
    }

    await renameFantasyIdentityForUid(uid, afterDisplayName);
  },
);

exports.getPublicUserProfile = onCall(async (request) => {
  const requesterUid = request.auth && request.auth.uid;
  if (!requesterUid) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const targetUid = `${(request.data && request.data.uid) || ""}`.trim();
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "uid is required");
  }

  const publicRef = db.collection("publicUserProfiles").doc(targetUid);
  const userRef = db.collection("users").doc(targetUid);
  const [publicSnapshot, userSnapshot] = await Promise.all([
    publicRef.get(),
    userRef.get(),
  ]);

  const currentPublic = sanitizePublicUserProfile(
    publicSnapshot.data() || {},
    targetUid,
  );

  let mergedProfile = currentPublic;
  if (userSnapshot.exists) {
    const userData = userSnapshot.data() || {};
    const userDisplayName = `${userData.displayName || ""}`
      .trim()
      .replace(/\s+/g, " ");
    const userNormalizedDisplayName =
      `${userData.normalizedDisplayName || ""}`.trim().toLowerCase() ||
      normalizeText(userDisplayName);
    const userPhotoUrl = `${userData.photoUrl || ""}`.trim();

    mergedProfile = {
      uid: targetUid,
      displayName: userDisplayName || currentPublic.displayName,
      normalizedDisplayName:
        userNormalizedDisplayName || currentPublic.normalizedDisplayName,
      photoUrl: userPhotoUrl || currentPublic.photoUrl,
    };
  }

  const shouldBackfill =
    mergedProfile.displayName !== currentPublic.displayName ||
    mergedProfile.normalizedDisplayName !== currentPublic.normalizedDisplayName ||
    mergedProfile.photoUrl !== currentPublic.photoUrl;

  if (shouldBackfill) {
    await publicRef.set(
      {
        ...mergedProfile,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  return {
    profile: mergedProfile,
  };
});

const K_LEAGUE_TEAM_DISPLAY_NAMES = {
  "Bucheon FC 1995": "부천FC 1995",
  "Gangwon FC": "강원 FC",
  "FC Anyang": "FC 안양",
  "Daejeon Citizen": "대전 하나 시티즌",
  "Daejeon Hana Citizen": "대전 하나 시티즌",
  "Gwangju FC": "광주 FC",
  "Jeju United FC": "제주 유나이티드",
  "Jeju SK": "제주 유나이티드",
  "Jeonbuk Motors": "전북 현대 모터스",
  "Jeonbuk Hyundai Motors": "전북 현대 모터스",
  "Incheon United": "인천 유나이티드",
  "Pohang Steelers": "포항 스틸러스",
  "FC Seoul": "FC 서울",
  "Ulsan Hyundai FC": "울산 HD",
  "Ulsan HD": "울산 HD",
  "Gimcheon Sangmu FC": "김천 상무",
  "Gimcheon Sangmu": "김천 상무",
};

const K_LEAGUE_ROUND_ADVANCE_DELAY_MS = 12 * 60 * 60 * 1000;
const K_LEAGUE_FIXTURE_DURATION_ESTIMATE_MINUTES = 120;

function kLeagueDisplayTeamName(value) {
  const trimmed = `${value == null ? "" : value}`.trim();
  return K_LEAGUE_TEAM_DISPLAY_NAMES[trimmed] || trimmed;
}

function canonicalKLeagueClub(value) {
  return `${value == null ? "" : value}`
    .trim()
    .replaceAll("제주 유나이티드", "제주 SK")
    .replaceAll("전북 현대 모터스", "전북 현대")
    .replaceAll("부천FC", "부천 FC");
}

function parseRoundNumber(round) {
  const match = /(\d+)$/.exec(`${round == null ? "" : round}`.trim());
  return Number.parseInt((match && match[1]) || "", 10) || 0;
}

function parseFixtureKickoffMs(fixtureMap) {
  const fixture = (fixtureMap && fixtureMap.fixture) || {};
  const parsed = Date.parse(`${fixture.date || ""}`);
  return Number.isFinite(parsed) ? parsed : null;
}

function estimateKLeagueFixtureEndMs(fixtureMap) {
  const kickoffMs = parseFixtureKickoffMs(fixtureMap);
  if (!kickoffMs) return null;
  const status = ((fixtureMap || {}).fixture || {}).status || {};
  const elapsed = Number.parseInt(`${status.elapsed || "0"}`, 10) || 0;
  const estimatedMinutes =
    elapsed > 0
      ? Math.max(K_LEAGUE_FIXTURE_DURATION_ESTIMATE_MINUTES, elapsed)
      : K_LEAGUE_FIXTURE_DURATION_ESTIMATE_MINUTES;
  return kickoffMs + estimatedMinutes * 60 * 1000;
}

function buildKLeagueRoundWindows(rawFixtures) {
  const byRound = new Map();
  for (const raw of Array.isArray(rawFixtures) ? rawFixtures : []) {
    const map = raw && typeof raw === "object" ? raw : {};
    const round = parseRoundNumber((map.league || {}).round || "");
    if (round <= 0) continue;
    const kickoffMs = parseFixtureKickoffMs(map);
    const endMs = estimateKLeagueFixtureEndMs(map);
    if (!kickoffMs || !endMs) continue;
    const existing = byRound.get(round);
    if (!existing) {
      byRound.set(round, { round, startMs: kickoffMs, endMs });
      continue;
    }
    byRound.set(round, {
      round,
      startMs: Math.min(existing.startMs, kickoffMs),
      endMs: Math.max(existing.endMs, endMs),
    });
  }
  return [...byRound.values()].sort((a, b) => a.round - b.round);
}

function roundAdvanceMs(window) {
  return window.endMs + K_LEAGUE_ROUND_ADVANCE_DELAY_MS;
}

function anchorKLeagueRoundForDraft(draftDateMs, windows) {
  if (!windows.length) return 1;
  if (draftDateMs < windows[0].startMs) return windows[0].round;
  for (const window of windows) {
    if (draftDateMs <= roundAdvanceMs(window)) return window.round;
  }
  return windows[windows.length - 1].round;
}

function currentKLeagueRoundAt(nowMs, windows) {
  if (!windows.length) return 1;
  if (nowMs < windows[0].startMs) return windows[0].round;
  for (const window of windows) {
    if (nowMs <= roundAdvanceMs(window)) return window.round;
  }
  return windows[windows.length - 1].round;
}

function currentFantasySoccerRoundAt({
  draftDateMs,
  roundCount,
  rawFixtures,
  nowMs,
}) {
  const safeRoundCount = Math.max(1, roundCount || 1);
  if (nowMs < draftDateMs) return 1;
  const windows = buildKLeagueRoundWindows(rawFixtures);
  if (!windows.length) return 1;
  const anchorRound = anchorKLeagueRoundForDraft(draftDateMs, windows);
  const currentRound = currentKLeagueRoundAt(nowMs, windows);
  const mappedRound = currentRound - anchorRound + 1;
  return Math.max(1, Math.min(safeRoundCount, mappedRound));
}

function fantasySoccerRoundForKLeagueRound({
  draftDateMs,
  roundCount,
  rawFixtures,
  kLeagueRound,
}) {
  const safeRoundCount = Math.max(1, roundCount || 1);
  const windows = buildKLeagueRoundWindows(rawFixtures);
  if (!windows.length) return 1;
  const anchorRound = anchorKLeagueRoundForDraft(draftDateMs, windows);
  const mappedRound = kLeagueRound - anchorRound + 1;
  return Math.max(1, Math.min(safeRoundCount, mappedRound));
}

function kstDateKeyFromMs(ms) {
  const kst = new Date(ms + KOREA_TIME_OFFSET_MS);
  const year = kst.getUTCFullYear();
  const month = `${kst.getUTCMonth() + 1}`.padStart(2, "0");
  const day = `${kst.getUTCDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function kboFantasyRoundContainsDay(dayKey, window) {
  return dayKey >= window.startKst && dayKey <= window.endKst;
}

function anchorKboRoundForDraft(draftDateMs) {
  if (!draftDateMs) return 1;
  const draftDay = kstDateKeyFromMs(draftDateMs);
  if (draftDay < KBO_FANTASY_ROUND_WINDOWS_2026[0].startKst) {
    return KBO_FANTASY_ROUND_WINDOWS_2026[0].round;
  }
  for (const window of KBO_FANTASY_ROUND_WINDOWS_2026) {
    if (draftDay < window.startKst) return window.round;
    if (kboFantasyRoundContainsDay(draftDay, window)) {
      return Math.min(KBO_FANTASY_TOTAL_ROUNDS_2026, window.round + 1);
    }
  }
  return KBO_FANTASY_ROUND_WINDOWS_2026[
    KBO_FANTASY_ROUND_WINDOWS_2026.length - 1
  ].round;
}

function currentKboRoundAt(nowMs) {
  const nowDay = kstDateKeyFromMs(nowMs);
  if (nowDay < KBO_FANTASY_ROUND_WINDOWS_2026[0].startKst) {
    return KBO_FANTASY_ROUND_WINDOWS_2026[0].round;
  }
  let currentRound = KBO_FANTASY_ROUND_WINDOWS_2026[0].round;
  for (const window of KBO_FANTASY_ROUND_WINDOWS_2026) {
    if (nowDay < window.startKst) return currentRound;
    if (kboFantasyRoundContainsDay(nowDay, window)) return window.round;
    currentRound = window.round;
  }
  return KBO_FANTASY_ROUND_WINDOWS_2026[
    KBO_FANTASY_ROUND_WINDOWS_2026.length - 1
  ].round;
}

function currentFantasyBaseballRoundAt({ draftDateMs, roundCount, nowMs }) {
  const safeRoundCount = Math.max(1, roundCount || 1);
  if (!draftDateMs || nowMs < draftDateMs) return 1;
  const anchorRound = anchorKboRoundForDraft(draftDateMs);
  const currentRound = currentKboRoundAt(nowMs);
  const mappedRound = currentRound - anchorRound + 1;
  return Math.max(1, Math.min(safeRoundCount, mappedRound));
}

function mappedKboRoundForFantasyRound({ draftDateMs, fantasyRound }) {
  const anchorRound = anchorKboRoundForDraft(draftDateMs);
  return Math.max(
    1,
    Math.min(KBO_FANTASY_TOTAL_ROUNDS_2026, anchorRound + fantasyRound - 1),
  );
}

function kboFantasyRoundHasStarted({ draftDateMs, fantasyRound, nowMs }) {
  if (!draftDateMs || fantasyRound <= 0) return false;
  const mappedRound = mappedKboRoundForFantasyRound({
    draftDateMs,
    fantasyRound,
  });
  const window = KBO_FANTASY_ROUND_WINDOWS_2026.find(
    (entry) => entry.round === mappedRound,
  );
  if (!window) return false;
  return kstDateKeyFromMs(nowMs) >= window.startKst;
}

function kboFantasyRoundForDateKey(dateKey) {
  for (const window of KBO_FANTASY_ROUND_WINDOWS_2026) {
    if (kboFantasyRoundContainsDay(dateKey, window)) return window.round;
  }
  return 0;
}

function parseKboMatchKickoffMs(match) {
  const dateUtc = `${(match && match.dateUtc) || ""}`.trim();
  const timeUtc = `${(match && match.timeUtc) || ""}`.trim();
  if (dateUtc && timeUtc) {
    const normalizedTime = /^\d{2}:\d{2}$/.test(timeUtc)
      ? `${timeUtc}:00`
      : timeUtc;
    const parsed = Date.parse(`${dateUtc}T${normalizedTime}Z`);
    if (Number.isFinite(parsed)) return parsed;
  }
  const date = `${(match && match.date) || ""}`.trim();
  const time = `${(match && match.time) || ""}`.trim();
  if (!date || !time) return null;
  const normalizedTime = /^\d{2}:\d{2}$/.test(time) ? `${time}:00` : time;
  const parsed = Date.parse(`${date}T${normalizedTime}+09:00`);
  return Number.isFinite(parsed) ? parsed : null;
}

function kboMatchDateKey(match) {
  const kickoffMs = parseKboMatchKickoffMs(match);
  if (kickoffMs) return kstDateKeyFromMs(kickoffMs);
  return `${(match && match.date) || ""}`.trim();
}

function isKboTerminalStatus(status) {
  const normalized = `${status == null ? "" : status}`.trim().toLowerCase();
  return ["played", "postponed", "cancelled", "canceled"].includes(normalized);
}

function isKboCancelledStatus(status) {
  const normalized = `${status == null ? "" : status}`.trim().toLowerCase();
  return ["postponed", "cancelled", "canceled"].includes(normalized);
}

function normalizeFrozenKboCancelledMatchSnapshot(data) {
  if (!data || typeof data !== "object") return null;
  const matchId = `${data.matchId || ""}`.trim();
  if (!matchId) return null;
  const originalRound =
    Number.parseInt(`${data.originalRound || "0"}`, 10) || 0;
  return {
    matchId,
    originalRound,
    originalDate: `${data.originalDate || ""}`.trim(),
    home: `${data.home || ""}`.trim(),
    away: `${data.away || ""}`.trim(),
    status: `${data.status || ""}`.trim(),
    detail:
      data.detail && typeof data.detail === "object" && !Array.isArray(data.detail) ?
        data.detail :
        null,
  };
}

async function loadFrozenKboCancelledMatches() {
  if (
    isCacheFreshFor(kboFrozenCancelledMatchesCache, CACHE_TTL_MS) &&
    kboFrozenCancelledMatchesCache.data
  ) {
    return kboFrozenCancelledMatchesCache.data;
  }

  const snapshot = await db.collection(KBO_FROZEN_CANCELLED_MATCH_COLLECTION).get();
  const list = [];
  const byId = new Map();
  snapshot.docs.forEach((doc) => {
    const normalized = normalizeFrozenKboCancelledMatchSnapshot(doc.data() || {});
    if (!normalized) return;
    list.push(normalized);
    byId.set(normalized.matchId, normalized);
  });
  const data = { list, byId };
  kboFrozenCancelledMatchesCache = { createdAt: Date.now(), data };
  return data;
}

async function captureFrozenKboCancelledMatchSnapshot(match) {
  const matchId =
    Number.parseInt(`${(match && match.id) || (match && match.matchId) || "0"}`, 10) || 0;
  if (matchId <= 0) return null;
  if (!isKboCancelledStatus(match && match.status)) return null;

  const existing = (await loadFrozenKboCancelledMatches()).byId.get(`${matchId}`);
  if (existing && existing.detail) return existing;

  let detail = null;
  try {
    detail = await fetchKboMatchDetails(matchId);
  } catch (error) {
    console.error(`Frozen KBO cancelled snapshot detail load failed for ${matchId}:`, error);
  }

  const payload = {
    matchId: `${matchId}`,
    originalRound: kboFantasyRoundForDateKey(kboMatchDateKey(match)),
    originalDate: kboMatchDateKey(match),
    home: `${(match && match.home) || ""}`.trim(),
    away: `${(match && match.away) || ""}`.trim(),
    status: `${(match && match.status) || ""}`.trim(),
    detail: detail ? refreshKboFantasyAnnotationsOnDetail(detail) : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (!(existing && existing.matchId)) {
    payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await db
    .collection(KBO_FROZEN_CANCELLED_MATCH_COLLECTION)
    .doc(`${matchId}`)
    .set(payload, { merge: true });

  kboFrozenCancelledMatchesCache = null;
  return normalizeFrozenKboCancelledMatchSnapshot(payload);
}

function buildFrozenKboCancelledMatchRoundMap(data) {
  const rows =
    Array.isArray(data && data.fantasyExcludedMatches) ?
      data.fantasyExcludedMatches :
      [];
  const byId = new Map();
  rows.forEach((row) => {
    const matchId = `${(row && row.matchId) || ""}`.trim();
    const originalRound =
      Number.parseInt(`${(row && row.originalRound) || "0"}`, 10) || 0;
    if (!matchId || originalRound <= 0) return;
    byId.set(matchId, originalRound);
  });
  return byId;
}

function lockedKboClubsForCurrentRound({
  draftDateMs,
  roundCount,
  rawMatches,
  nowMs,
}) {
  const fantasyRound = currentFantasyBaseballRoundAt({
    draftDateMs,
    roundCount,
    nowMs,
  });
  if (!kboFantasyRoundHasStarted({ draftDateMs, fantasyRound, nowMs })) {
    return new Set();
  }
  const targetRound = mappedKboRoundForFantasyRound({
    draftDateMs,
    fantasyRound,
  });
  const todayKey = kstDateKeyFromMs(nowMs);
  const todayMatches = (Array.isArray(rawMatches) ? rawMatches : [])
    .filter(
      (match) =>
        kboFantasyRoundForDateKey(kboMatchDateKey(match)) === targetRound,
    )
    .filter((match) => kboMatchDateKey(match) === todayKey);
  if (!todayMatches.length) return new Set();

  const lockedClubs = new Set();
  let anyStarted = false;
  let allTerminal = true;
  let unlocksAtMs = null;
  for (const match of todayMatches) {
    const kickoffMs = parseKboMatchKickoffMs(match);
    if (kickoffMs) {
      unlocksAtMs = Math.max(
        unlocksAtMs || 0,
        kickoffMs + KBO_LOCK_MATCH_DURATION_MS + KBO_DAILY_UNLOCK_DELAY_MS,
      );
    }
    const started = kickoffMs
      ? kickoffMs <= nowMs
      : isKboTerminalStatus(match && match.status) ||
        `${(match && match.status) || ""}`.trim().toLowerCase() === "playing" ||
        `${(match && match.status) || ""}`.trim().toLowerCase() === "live";
    if (!started) {
      allTerminal = false;
      continue;
    }
    anyStarted = true;
    allTerminal = allTerminal && isKboTerminalStatus(match && match.status);
    lockedClubs.add(normalizeKboTeamName((match && match.home) || ""));
    lockedClubs.add(normalizeKboTeamName((match && match.away) || ""));
  }
  if (!anyStarted) return new Set();
  if (allTerminal && unlocksAtMs && nowMs >= unlocksAtMs) {
    return new Set();
  }
  return lockedClubs;
}

function kboRosterLockPushState({
  draftDateMs,
  roundCount,
  rawMatches,
  nowMs,
}) {
  const fantasyRound = currentFantasyBaseballRoundAt({
    draftDateMs,
    roundCount,
    nowMs,
  });
  const phase = "pre_lock";
  if (!kboFantasyRoundHasStarted({ draftDateMs, fantasyRound, nowMs })) {
    return {
      round: fantasyRound,
      phase,
      lockStartsAtMs: null,
      unlocksAtMs: null,
    };
  }

  const targetRound = mappedKboRoundForFantasyRound({
    draftDateMs,
    fantasyRound,
  });
  const roundMatches = (Array.isArray(rawMatches) ? rawMatches : []).filter(
    (match) => kboFantasyRoundForDateKey(kboMatchDateKey(match)) === targetRound,
  );
  if (!roundMatches.length) {
    return {
      round: fantasyRound,
      phase,
      lockStartsAtMs: null,
      unlocksAtMs: null,
    };
  }

  const matchWindowsByDate = new Map();
  roundMatches.forEach((match) => {
    const dateKey = kboMatchDateKey(match);
    if (!dateKey) return;
    if (!matchWindowsByDate.has(dateKey)) {
      matchWindowsByDate.set(dateKey, []);
    }
    matchWindowsByDate.get(dateKey).push(match);
  });

  const justUnlockedWindow = [...matchWindowsByDate.values()]
    .map((matches) => {
      const kickoffTimes = matches
        .map((match) => parseKboMatchKickoffMs(match))
        .filter((value) => Number.isFinite(value));
      if (!kickoffTimes.length) return null;
      return {
        lockStartsAtMs: Math.min(...kickoffTimes),
        unlocksAtMs: Math.max(
          ...kickoffTimes.map((kickoffMs) =>
            kickoffMs + KBO_LOCK_MATCH_DURATION_MS + KBO_DAILY_UNLOCK_DELAY_MS,
          ),
        ),
      };
    })
    .filter(Boolean)
    .find((window) => {
      return (
        Number.isFinite(window.unlocksAtMs) &&
        nowMs >= window.unlocksAtMs &&
        nowMs - window.unlocksAtMs <= PUSH_EVENT_WINDOW_MS
      );
    });
  if (justUnlockedWindow) {
    return {
      round: fantasyRound,
      phase: "unlocked",
      lockStartsAtMs: justUnlockedWindow.lockStartsAtMs,
      unlocksAtMs: justUnlockedWindow.unlocksAtMs,
    };
  }

  const todayKey = kstDateKeyFromMs(nowMs);
  const todayMatches = matchWindowsByDate.get(todayKey) || [];
  if (!todayMatches.length) {
    return {
      round: fantasyRound,
      phase,
      lockStartsAtMs: null,
      unlocksAtMs: null,
    };
  }

  const kickoffTimes = todayMatches
    .map((match) => parseKboMatchKickoffMs(match))
    .filter((value) => Number.isFinite(value));
  const lockStartsAtMs = kickoffTimes.length ? Math.min(...kickoffTimes) : null;

  let unlocksAtMs = null;
  let anyStarted = false;
  let allTerminal = true;
  for (const match of todayMatches) {
    const kickoffMs = parseKboMatchKickoffMs(match);
    if (kickoffMs) {
      unlocksAtMs = Math.max(
        unlocksAtMs || 0,
        kickoffMs + KBO_LOCK_MATCH_DURATION_MS + KBO_DAILY_UNLOCK_DELAY_MS,
      );
    }
    const status = `${(match && match.status) || ""}`.trim().toLowerCase();
    const started = kickoffMs
      ? kickoffMs <= nowMs
      : isKboTerminalStatus(status) ||
        status === "playing" ||
        status === "live";
    if (!started) {
      allTerminal = false;
      continue;
    }
    anyStarted = true;
    allTerminal = allTerminal && isKboTerminalStatus(status);
  }

  if (!anyStarted) {
    return {
      round: fantasyRound,
      phase,
      lockStartsAtMs,
      unlocksAtMs,
    };
  }

  if (allTerminal && unlocksAtMs && nowMs >= unlocksAtMs) {
    return {
      round: fantasyRound,
      phase: "unlocked",
      lockStartsAtMs,
      unlocksAtMs,
    };
  }

  return {
    round: fantasyRound,
    phase: "locked",
    lockStartsAtMs,
    unlocksAtMs,
  };
}

function mappedKLeagueRoundForFantasyRound({
  draftDateMs,
  fantasyRound,
  rawFixtures,
}) {
  const windows = buildKLeagueRoundWindows(rawFixtures);
  if (!windows.length) return Math.max(1, fantasyRound);
  const anchorRound = anchorKLeagueRoundForDraft(draftDateMs, windows);
  const mappedRound = anchorRound + fantasyRound - 1;
  return Math.max(
    windows[0].round,
    Math.min(windows[windows.length - 1].round, mappedRound),
  );
}

function fixtureHasStarted(fixtureMap, nowMs) {
  const fixture = (fixtureMap && fixtureMap.fixture) || {};
  const kickoffMs = parseFixtureKickoffMs(fixtureMap);
  if (!kickoffMs) return false;
  const status = fixture.status || {};
  const statusShort = `${status.short || ""}`.trim().toUpperCase();
  const elapsed = `${status.elapsed || ""}`.trim();
  const extra = `${status.extra || ""}`.trim();
  return (
    kickoffMs <= nowMs ||
    ["FT", "AET", "PEN"].includes(statusShort) ||
    elapsed !== "" ||
    extra !== ""
  );
}

function extractFantasyPlayerIdentity(player) {
  const explicitId = `${(player && player.playerId) || ""}`.trim();
  if (explicitId) return explicitId;
  const club = canonicalKLeagueClub(
    kLeagueDisplayTeamName(`${(player && player.club) || ""}`),
  );
  const number =
    Number.parseInt(`${(player && player.number) || "0"}`, 10) || 0;
  const name = `${(player && player.name) || ""}`.trim();
  if (club && number > 0) return `${club}|${number}|${name}`;
  return name;
}

function buildPlayerMap(players) {
  const map = new Map();
  for (const player of Array.isArray(players) ? players : []) {
    map.set(extractFantasyPlayerIdentity(player), player);
  }
  return map;
}

function sanitizeKboRoundScoreStates(value) {
  return (Array.isArray(value) ? value : [])
    .map((raw) => (raw && typeof raw === "object" ? raw : null))
    .filter(Boolean)
    .map((item) => {
      const round = Number.parseInt(`${item.round || "0"}`, 10) || 0;
      const starterBaselines = {};
      const rawBaselines =
        item.starterBaselines && typeof item.starterBaselines === "object"
          ? item.starterBaselines
          : {};
      Object.entries(rawBaselines).forEach(([key, value]) => {
        const normalizedKey = `${key || ""}`.trim();
        if (!normalizedKey) return;
        starterBaselines[normalizedKey] = Number(value) || 0;
      });
      return {
        round,
        bankedScore: Number(item.bankedScore) || 0,
        starterBaselines,
        updatedAt: `${item.updatedAt || ""}`.trim() || new Date().toISOString(),
      };
    })
    .filter((item) => item.round > 0)
    .sort((a, b) => a.round - b.round);
}

function rosterMembershipForPlayerId(playerId, startingMap, benchMap) {
  if (startingMap.has(playerId)) return "starting";
  if (benchMap.has(playerId)) return "bench";
  return "none";
}

function lockedClubsForCurrentRound({
  draftDateMs,
  roundCount,
  rawFixtures,
  nowMs,
}) {
  const fantasyRound = currentFantasySoccerRoundAt({
    draftDateMs,
    roundCount,
    rawFixtures,
    nowMs,
  });
  const targetRound = mappedKLeagueRoundForFantasyRound({
    draftDateMs,
    fantasyRound,
    rawFixtures,
  });
  const windows = buildKLeagueRoundWindows(rawFixtures);
  const window = windows.find((item) => item.round === targetRound);
  if (!window || nowMs >= roundAdvanceMs(window)) return new Set();

  const lockedClubs = new Set();
  for (const raw of Array.isArray(rawFixtures) ? rawFixtures : []) {
    const map = raw && typeof raw === "object" ? raw : {};
    const round = parseRoundNumber((map.league || {}).round || "");
    if (round !== targetRound || !fixtureHasStarted(map, nowMs)) continue;
    const teams = map.teams || {};
    const homeClub = canonicalKLeagueClub(
      kLeagueDisplayTeamName((teams.home || {}).name || ""),
    );
    const awayClub = canonicalKLeagueClub(
      kLeagueDisplayTeamName((teams.away || {}).name || ""),
    );
    if (homeClub) lockedClubs.add(homeClub);
    if (awayClub) lockedClubs.add(awayClub);
  }
  return lockedClubs;
}

function soccerRosterLockPushState({
  draftDateMs,
  roundCount,
  rawFixtures,
  nowMs,
}) {
  const windows = buildKLeagueRoundWindows(rawFixtures);
  const justUnlockedWindow = [...windows]
    .reverse()
    .find((item) => {
      const unlockedAtMs = roundAdvanceMs(item);
      return (
        nowMs >= unlockedAtMs &&
        nowMs - unlockedAtMs <= PUSH_EVENT_WINDOW_MS
      );
    });
  if (justUnlockedWindow) {
    return {
      round: fantasySoccerRoundForKLeagueRound({
        draftDateMs,
        roundCount,
        rawFixtures,
        kLeagueRound: justUnlockedWindow.round,
      }),
      phase: "unlocked",
      lockStartsAtMs: justUnlockedWindow.startMs,
      unlocksAtMs: roundAdvanceMs(justUnlockedWindow),
    };
  }

  const fantasyRound = currentFantasySoccerRoundAt({
    draftDateMs,
    roundCount,
    rawFixtures,
    nowMs,
  });
  const targetRound = mappedKLeagueRoundForFantasyRound({
    draftDateMs,
    fantasyRound,
    rawFixtures,
  });
  const window = windows.find((item) => item.round === targetRound);
  if (!window) {
    return {
      round: fantasyRound,
      phase: "pre_lock",
      lockStartsAtMs: null,
      unlocksAtMs: null,
    };
  }

  const roundFixtures = (Array.isArray(rawFixtures) ? rawFixtures : [])
    .map((raw) => (raw && typeof raw === "object" ? raw : {}))
    .filter(
      (fixture) => parseRoundNumber((fixture.league || {}).round || "") === targetRound,
    );
  const kickoffTimes = roundFixtures
    .map((fixture) => parseFixtureKickoffMs(fixture))
    .filter((value) => Number.isFinite(value));
  const lockStartsAtMs = kickoffTimes.length ? Math.min(...kickoffTimes) : window.startMs;
  const unlocksAtMs = roundAdvanceMs(window);
  if (nowMs >= unlocksAtMs) {
    return {
      round: fantasyRound,
      phase: "unlocked",
      lockStartsAtMs,
      unlocksAtMs,
    };
  }
  const lockedClubs = lockedClubsForCurrentRound({
    draftDateMs,
    roundCount,
    rawFixtures,
    nowMs,
  });
  return {
    round: fantasyRound,
    phase: lockedClubs.size > 0 ? "locked" : "pre_lock",
    lockStartsAtMs,
    unlocksAtMs,
  };
}

function resolveLeadershipPlayerId(players, explicitId, fallbackName) {
  const normalizedId = `${explicitId || ""}`.trim();
  if (normalizedId) return normalizedId;
  const targetName = `${fallbackName || ""}`.trim();
  if (!targetName) return "";
  for (const player of Array.isArray(players) ? players : []) {
    if (`${(player && player.name) || ""}`.trim() !== targetName) continue;
    return extractFantasyPlayerIdentity(player);
  }
  return "";
}

function validateLockedFantasyRoster({
  existingTeam,
  nextRoster,
  nextStarting,
  nextBench,
  nextCaptainName,
  nextViceCaptainName,
  nextCaptainPlayerId,
  nextViceCaptainPlayerId,
  lockedClubs,
  normalizeClub = (value) =>
    canonicalKLeagueClub(kLeagueDisplayTeamName(value)),
}) {
  if (!(lockedClubs instanceof Set) || lockedClubs.size === 0) return;

  const previousStarting = Array.isArray(existingTeam && existingTeam.starting)
    ? existingTeam.starting
    : [];
  const previousBench = Array.isArray(existingTeam && existingTeam.bench)
    ? existingTeam.bench
    : [];
  const previousStartingMap = buildPlayerMap(previousStarting);
  const previousBenchMap = buildPlayerMap(previousBench);
  const nextStartingMap = buildPlayerMap(nextStarting);
  const nextBenchMap = buildPlayerMap(nextBench);
  const allIds = new Set([
    ...previousStartingMap.keys(),
    ...previousBenchMap.keys(),
    ...nextStartingMap.keys(),
    ...nextBenchMap.keys(),
  ]);

  for (const playerId of allIds) {
    const player =
      nextStartingMap.get(playerId) ||
      nextBenchMap.get(playerId) ||
      previousStartingMap.get(playerId) ||
      previousBenchMap.get(playerId);
    if (!player) continue;
    const club = normalizeClub(`${(player && player.club) || ""}`);
    if (!club || !lockedClubs.has(club)) continue;
    const previousMembership = rosterMembershipForPlayerId(
      playerId,
      previousStartingMap,
      previousBenchMap,
    );
    const nextMembership = rosterMembershipForPlayerId(
      playerId,
      nextStartingMap,
      nextBenchMap,
    );
    if (previousMembership !== nextMembership) {
      throw new HttpsError(
        "failed-precondition",
        "A locked player cannot be moved, added, or removed.",
      );
    }
  }

  const previousCaptainId = resolveLeadershipPlayerId(
    previousStarting,
    existingTeam && existingTeam.captainPlayerId,
    existingTeam && existingTeam.captainName,
  );
  const previousViceCaptainId = resolveLeadershipPlayerId(
    previousStarting,
    existingTeam && existingTeam.viceCaptainPlayerId,
    existingTeam && existingTeam.viceCaptainName,
  );
  const resolvedNextCaptainId = resolveLeadershipPlayerId(
    nextStarting,
    nextCaptainPlayerId,
    nextCaptainName,
  );
  const resolvedNextViceCaptainId = resolveLeadershipPlayerId(
    nextStarting,
    nextViceCaptainPlayerId,
    nextViceCaptainName,
  );

  const leadershipIds = [
    [previousCaptainId, resolvedNextCaptainId],
    [previousViceCaptainId, resolvedNextViceCaptainId],
  ];
  for (const [beforeId, afterId] of leadershipIds) {
    if (beforeId === afterId) continue;
    const beforePlayer = beforeId
      ? previousStartingMap.get(beforeId) || previousBenchMap.get(beforeId)
      : null;
    const afterPlayer = afterId
      ? nextStartingMap.get(afterId) || nextBenchMap.get(afterId)
      : null;
    const beforeClub = beforePlayer
      ? normalizeClub(`${beforePlayer.club || ""}`)
      : "";
    const afterClub = afterPlayer
      ? normalizeClub(`${afterPlayer.club || ""}`)
      : "";
    if (
      (beforeClub && lockedClubs.has(beforeClub)) ||
      (afterClub && lockedClubs.has(afterClub))
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Captain and vice-captain selections are locked for started players.",
      );
    }
  }

  if (Array.isArray(nextRoster) && nextRoster.length) {
    const nextRosterMap = buildPlayerMap(nextRoster);
    for (const playerId of nextRosterMap.keys()) {
      if (!nextStartingMap.has(playerId) && !nextBenchMap.has(playerId)) {
        throw new HttpsError(
          "invalid-argument",
          "Roster, starting, and bench payloads are inconsistent.",
        );
      }
    }
    for (const playerId of [
      ...nextStartingMap.keys(),
      ...nextBenchMap.keys(),
    ]) {
      if (!nextRosterMap.has(playerId)) {
        throw new HttpsError(
          "invalid-argument",
          "Roster, starting, and bench payloads are inconsistent.",
        );
      }
    }
  }
}

function normalizeFantasyPosition(value) {
  return `${value || ""}`.trim().toUpperCase();
}

function buildSoccerStartingFromRoster(roster) {
  const byPosition = (position) =>
    roster
      .filter(
        (player) =>
          normalizeFantasyPosition(player && player.position) === position,
      )
      .sort(
        (a, b) => (Number(b && b.score) || 0) - (Number(a && a.score) || 0),
      );
  const gks = byPosition("GK");
  const dfs = byPosition("DF");
  const mfs = byPosition("MF");
  const fws = byPosition("FW");
  const formations = [
    [4, 4, 2],
    [4, 3, 3],
    [3, 4, 3],
    [4, 5, 1],
    [3, 5, 2],
    [5, 4, 1],
    [5, 2, 3],
  ];
  for (const [dfNeed, mfNeed, fwNeed] of formations) {
    if (
      !gks.length ||
      dfs.length < dfNeed ||
      mfs.length < mfNeed ||
      fws.length < fwNeed
    ) {
      continue;
    }
    return [
      gks[0],
      ...dfs.slice(0, dfNeed),
      ...mfs.slice(0, mfNeed),
      ...fws.slice(0, fwNeed),
    ];
  }
  return roster.slice(0, 11);
}

function isBaseballHitterPosition(position) {
  switch (normalizeFantasyPosition(position)) {
    case "C":
    case "IF":
    case "OF":
    case "DH":
      return true;
    default:
      return false;
  }
}

function buildBaseballStartingFromRoster(roster) {
  const sortedPlayers = (position) =>
    roster
      .filter(
        (player) =>
          normalizeFantasyPosition(player && player.position) === position,
      )
      .sort(
        (a, b) => (Number(b && b.score) || 0) - (Number(a && a.score) || 0),
      );
  const catchers = sortedPlayers("C");
  const pitchers = sortedPlayers("P");
  const infielders = sortedPlayers("IF");
  const outfielders = sortedPlayers("OF");
  const starting = [
    ...catchers.slice(0, 1),
    ...pitchers.slice(0, 1),
    ...infielders.slice(0, 4),
    ...outfielders.slice(0, 3),
  ];
  const usedIds = new Set(
    starting.map((player) => extractFantasyPlayerIdentity(player)),
  );
  const dhCandidates = roster
    .filter(
      (player) =>
        isBaseballHitterPosition(player && player.position) &&
        !usedIds.has(extractFantasyPlayerIdentity(player)),
    )
    .sort((a, b) => (Number(b && b.score) || 0) - (Number(a && a.score) || 0));
  if (dhCandidates.length) {
    starting.push(dhCandidates[0]);
  }
  return starting;
}

function buildBenchFromRoster(roster, starting) {
  const startingIds = new Set(
    (Array.isArray(starting) ? starting : []).map((player) =>
      extractFantasyPlayerIdentity(player),
    ),
  );
  return (Array.isArray(roster) ? roster : []).filter(
    (player) => !startingIds.has(extractFantasyPlayerIdentity(player)),
  );
}

function sanitizeTradePlayer(player) {
  return {
    name: `${(player && player.name) || ""}`.trim(),
    position: `${(player && player.position) || ""}`.trim(),
    score: Number(player && player.score) || 0,
    club: `${(player && player.club) || ""}`.trim(),
    number: Number.parseInt(`${(player && player.number) || "0"}`, 10) || 0,
    playerId: `${(player && player.playerId) || ""}`.trim(),
  };
}

function sanitizeTradePlayerList(value) {
  return (Array.isArray(value) ? value : [])
    .map((player) => sanitizeTradePlayer(player))
    .filter((player) => player.name);
}

function playersEquivalent(a, b) {
  const aId = `${(a && a.playerId) || ""}`.trim();
  const bId = `${(b && b.playerId) || ""}`.trim();
  if (aId && bId) return aId === bId;
  const aIdentity = extractFantasyPlayerIdentity(a);
  const bIdentity = extractFantasyPlayerIdentity(b);
  if (aIdentity && bIdentity && aIdentity === bIdentity) return true;
  return (
    normalizeText(a && a.name) === normalizeText(b && b.name) &&
    normalizeText(a && a.club) === normalizeText(b && b.club) &&
    normalizeFantasyPosition(a && a.position) ===
      normalizeFantasyPosition(b && b.position) &&
    (Number(a && a.number) || 0) === (Number(b && b.number) || 0)
  );
}

function resolveTradePlayersFromRoster(team, requestedPlayers) {
  const roster = Array.isArray(team && team.roster) ? team.roster : [];
  const remaining = [...roster];
  const resolved = [];
  for (const requested of sanitizeTradePlayerList(requestedPlayers)) {
    const index = remaining.findIndex((player) =>
      playersEquivalent(player, requested),
    );
    if (index < 0) {
      throw new HttpsError(
        "failed-precondition",
        `Trade player not found in roster: ${requested.name}`,
      );
    }
    resolved.push(remaining[index]);
    remaining.splice(index, 1);
  }
  return resolved;
}

function nextRosterAfterTrade(roster, outgoingPlayers, incomingPlayers) {
  const outgoingIds = new Set(
    outgoingPlayers.map((player) => extractFantasyPlayerIdentity(player)),
  );
  return [
    ...(Array.isArray(roster) ? roster : []).filter(
      (player) => !outgoingIds.has(extractFantasyPlayerIdentity(player)),
    ),
    ...incomingPlayers,
  ];
}

function normalizeLeadershipForTeam(team, starting) {
  const startingMap = buildPlayerMap(starting);
  const captainId = resolveLeadershipPlayerId(
    starting,
    team && team.captainPlayerId,
    team && team.captainName,
  );
  const captain = captainId ? startingMap.get(captainId) : null;
  let viceCaptainId = resolveLeadershipPlayerId(
    starting,
    team && team.viceCaptainPlayerId,
    team && team.viceCaptainName,
  );
  if (viceCaptainId && viceCaptainId === captainId) {
    viceCaptainId = "";
  }
  const viceCaptain = viceCaptainId ? startingMap.get(viceCaptainId) : null;
  return {
    captainName: captain ? captain.name : null,
    viceCaptainName: viceCaptain ? viceCaptain.name : null,
    captainPlayerId: captain ? extractFantasyPlayerIdentity(captain) : null,
    viceCaptainPlayerId: viceCaptain
      ? extractFantasyPlayerIdentity(viceCaptain)
      : null,
  };
}

function normalizeFantasyTeamAfterTrade(team, roster, isSoccerLeague) {
  const nextRoster = Array.isArray(roster) ? [...roster] : [];
  const starting = isSoccerLeague
    ? buildSoccerStartingFromRoster(nextRoster)
    : buildBaseballStartingFromRoster(nextRoster);
  const bench = buildBenchFromRoster(nextRoster, starting);
  const leadership = normalizeLeadershipForTeam(team, starting);
  return {
    ...team,
    roster: nextRoster,
    starting,
    bench,
    ...leadership,
  };
}

exports.updateFantasyRoster = onCall(
  {
    secrets: [
      "API_SPORTS_KEY",
      "DSG_CLIENT",
      "DSG_USERNAME",
      "DSG_PASSWORD",
      "DSG_AUTHKEY",
    ],
  },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const leagueId = `${(request.data && request.data.leagueId) || ""}`.trim();
    if (!leagueId) {
      throw new HttpsError("invalid-argument", "leagueId is required");
    }

    const teamName = `${(request.data && request.data.teamName) || ""}`.trim();
    const roster = Array.isArray(request.data && request.data.roster)
      ? request.data.roster
      : [];
    const starting = Array.isArray(request.data && request.data.starting)
      ? request.data.starting
      : [];
    const bench = Array.isArray(request.data && request.data.bench)
      ? request.data.bench
      : [];
    const hasCaptainName = !!(
      request.data &&
      Object.prototype.hasOwnProperty.call(request.data, "captainName")
    );
    const hasViceCaptainName = !!(
      request.data &&
      Object.prototype.hasOwnProperty.call(request.data, "viceCaptainName")
    );
    const hasCaptainPlayerId = !!(
      request.data &&
      Object.prototype.hasOwnProperty.call(request.data, "captainPlayerId")
    );
    const hasViceCaptainPlayerId = !!(
      request.data &&
      Object.prototype.hasOwnProperty.call(request.data, "viceCaptainPlayerId")
    );
    const captainName =
      `${(request.data && request.data.captainName) || ""}`.trim() || null;
    const viceCaptainName =
      `${(request.data && request.data.viceCaptainName) || ""}`.trim() || null;
    const captainPlayerId =
      `${(request.data && request.data.captainPlayerId) || ""}`.trim() || null;
    const viceCaptainPlayerId =
      `${(request.data && request.data.viceCaptainPlayerId) || ""}`.trim() ||
      null;
    const hasKboRoundScoreStates = !!(
      request.data &&
      Object.prototype.hasOwnProperty.call(request.data, "kboRoundScoreStates")
    );
    const kboRoundScoreStates = sanitizeKboRoundScoreStates(
      request.data && request.data.kboRoundScoreStates,
    );

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

      const fantasyTeams = Array.isArray(data.fantasyTeams)
        ? data.fantasyTeams.map((team) => ({ ...team }))
        : [];
      if (!fantasyTeams.length) {
        throw new HttpsError("failed-precondition", "Fantasy teams not ready");
      }

      const teamIndex = fantasyTeams.findIndex(
        (team) =>
          (team && `${team.uid || ""}` === uid) ||
          (teamName && team && `${team.teamName || ""}` === teamName),
      );
      if (teamIndex < 0) {
        throw new HttpsError("permission-denied", "Fantasy team not found");
      }

      const sport = `${data.sport || "soccer"}`.trim().toLowerCase();
      const isSoccerLeague =
        sport === "soccer" ||
        sport === "k league" ||
        sport === "k-league" ||
        sport === "kleague";
      if (isSoccerLeague) {
        const rawDraftDate =
          data.draftDateTime || data.draftAt || data.draftTime;
        const draftDateMs = timestampToMillis(rawDraftDate);
        if (draftDateMs) {
          const roundCount =
            Number.parseInt(`${data.roundCount || "1"}`, 10) || 1;
          const leagueData = await fetchKLeagueData();
          const rawFixtures = Array.isArray(leagueData && leagueData.fixtures)
            ? leagueData.fixtures
            : [];
          const lockedClubs = lockedClubsForCurrentRound({
            draftDateMs,
            roundCount,
            rawFixtures,
            nowMs: Date.now(),
          });
          validateLockedFantasyRoster({
            existingTeam: fantasyTeams[teamIndex],
            nextRoster: roster,
            nextStarting: starting,
            nextBench: bench,
            nextCaptainName: hasCaptainName
              ? captainName
              : fantasyTeams[teamIndex].captainName,
            nextViceCaptainName: hasViceCaptainName
              ? viceCaptainName
              : fantasyTeams[teamIndex].viceCaptainName,
            nextCaptainPlayerId: hasCaptainPlayerId
              ? captainPlayerId
              : fantasyTeams[teamIndex].captainPlayerId,
            nextViceCaptainPlayerId: hasViceCaptainPlayerId
              ? viceCaptainPlayerId
              : fantasyTeams[teamIndex].viceCaptainPlayerId,
            lockedClubs,
            normalizeClub: (value) =>
              canonicalKLeagueClub(kLeagueDisplayTeamName(value)),
          });
        }
      } else {
        const rawDraftDate =
          data.draftDateTime || data.draftAt || data.draftTime;
        const draftDateMs = timestampToMillis(rawDraftDate);
        if (draftDateMs) {
          const roundCount =
            Number.parseInt(`${data.roundCount || "1"}`, 10) || 1;
          const leagueData = await fetchKboLeagueData();
          const rawMatches = Array.isArray(leagueData && leagueData.matches)
            ? leagueData.matches
            : [];
          const lockedClubs = lockedKboClubsForCurrentRound({
            draftDateMs,
            roundCount,
            rawMatches,
            nowMs: Date.now(),
          });
          validateLockedFantasyRoster({
            existingTeam: fantasyTeams[teamIndex],
            nextRoster: roster,
            nextStarting: starting,
            nextBench: bench,
            nextCaptainName: hasCaptainName
              ? captainName
              : fantasyTeams[teamIndex].captainName,
            nextViceCaptainName: hasViceCaptainName
              ? viceCaptainName
              : fantasyTeams[teamIndex].viceCaptainName,
            nextCaptainPlayerId: hasCaptainPlayerId
              ? captainPlayerId
              : fantasyTeams[teamIndex].captainPlayerId,
            nextViceCaptainPlayerId: hasViceCaptainPlayerId
              ? viceCaptainPlayerId
              : fantasyTeams[teamIndex].viceCaptainPlayerId,
            lockedClubs,
            normalizeClub: (value) => normalizeKboTeamName(value),
          });
        }
      }

      fantasyTeams[teamIndex] = {
        ...fantasyTeams[teamIndex],
        uid: `${fantasyTeams[teamIndex].uid || uid}`,
        teamName: `${fantasyTeams[teamIndex].teamName || teamName}`,
        roster,
        starting,
        bench,
        ...(hasCaptainName ? { captainName } : {}),
        ...(hasViceCaptainName ? { viceCaptainName } : {}),
        ...(hasCaptainPlayerId ? { captainPlayerId } : {}),
        ...(hasViceCaptainPlayerId ? { viceCaptainPlayerId } : {}),
        ...(hasKboRoundScoreStates ? { kboRoundScoreStates } : {}),
      };

      transaction.update(leagueRef, {
        fantasyTeams,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        leagueId,
        fantasyTeams,
      };
    });
  },
);

exports.respondToTradeRequest = onCall(
  {
    secrets: [
      "API_SPORTS_KEY",
      "DSG_CLIENT",
      "DSG_USERNAME",
      "DSG_PASSWORD",
      "DSG_AUTHKEY",
    ],
  },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const requestId =
      `${(request.data && request.data.requestId) || ""}`.trim();
    const action = `${(request.data && request.data.action) || ""}`
      .trim()
      .toLowerCase();
    const rawKboRoundScoreStatesByTeam =
      request.data &&
      request.data.kboRoundScoreStatesByTeam &&
      typeof request.data.kboRoundScoreStatesByTeam === "object"
        ? request.data.kboRoundScoreStatesByTeam
        : {};
    if (!requestId) {
      throw new HttpsError("invalid-argument", "requestId is required");
    }
    if (!["accept", "decline"].includes(action)) {
      throw new HttpsError(
        "invalid-argument",
        "action must be accept or decline",
      );
    }

    const tradeRef = db.collection("tradeRequests").doc(requestId);
    return db.runTransaction(async (transaction) => {
      const tradeSnapshot = await transaction.get(tradeRef);
      if (!tradeSnapshot.exists) {
        throw new HttpsError("not-found", "Trade request not found");
      }

      const trade = tradeSnapshot.data() || {};
      const leagueId = `${trade.leagueId || ""}`.trim();
      const status = `${trade.status || ""}`.trim().toLowerCase();
      const fromUid = `${trade.fromUid || ""}`.trim();
      const toUid = `${trade.toUid || ""}`.trim();
      if (!leagueId || !fromUid || !toUid) {
        throw new HttpsError("failed-precondition", "Trade request is invalid");
      }
      if (![fromUid, toUid].includes(uid)) {
        throw new HttpsError("permission-denied", "Not a trade participant");
      }
      if (uid !== toUid) {
        throw new HttpsError(
          "permission-denied",
          "Only the recipient can respond",
        );
      }
      if (status !== "pending") {
        return {
          requestId,
          status,
          leagueId,
        };
      }

      const updatePayload = {
        status: action === "accept" ? "accepted" : "declined",
        responderUid: uid,
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (action === "decline") {
        transaction.update(tradeRef, updatePayload);
        return {
          requestId,
          status: "declined",
          leagueId,
        };
      }

      const leagueRef = db.collection("leagues").doc(leagueId);
      const leagueSnapshot = await transaction.get(leagueRef);
      if (!leagueSnapshot.exists) {
        throw new HttpsError("not-found", "League not found");
      }

      const league = leagueSnapshot.data() || {};
      const members = Array.isArray(league.members) ? [...league.members] : [];
      if (!members.includes(fromUid) || !members.includes(toUid)) {
        throw new HttpsError(
          "failed-precondition",
          "Trade participants are no longer in the league",
        );
      }

      const fantasyTeams = Array.isArray(league.fantasyTeams)
        ? league.fantasyTeams.map((team) => ({ ...team }))
        : [];
      const fromIndex = fantasyTeams.findIndex(
        (team) =>
          `${(team && team.uid) || ""}` === fromUid ||
          `${(team && team.teamName) || ""}`.trim() ===
            `${trade.fromTeamName || ""}`.trim(),
      );
      const toIndex = fantasyTeams.findIndex(
        (team) =>
          `${(team && team.uid) || ""}` === toUid ||
          `${(team && team.teamName) || ""}`.trim() ===
            `${trade.toTeamName || ""}`.trim(),
      );
      if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) {
        throw new HttpsError(
          "failed-precondition",
          "Trade teams could not be resolved",
        );
      }

      const fromTeam = fantasyTeams[fromIndex];
      const toTeam = fantasyTeams[toIndex];
      const fromPlayers = resolveTradePlayersFromRoster(
        fromTeam,
        trade.fromPlayers,
      );
      const toPlayers = resolveTradePlayersFromRoster(toTeam, trade.toPlayers);
      const nextFromRoster = nextRosterAfterTrade(
        fromTeam.roster,
        fromPlayers,
        toPlayers,
      );
      const nextToRoster = nextRosterAfterTrade(
        toTeam.roster,
        toPlayers,
        fromPlayers,
      );

      const sport = `${league.sport || "soccer"}`.trim().toLowerCase();
      const isSoccerLeague =
        sport === "soccer" ||
        sport === "k league" ||
        sport === "k-league" ||
        sport === "kleague";
      const nextFromTeam = normalizeFantasyTeamAfterTrade(
        fromTeam,
        nextFromRoster,
        isSoccerLeague,
      );
      const nextToTeam = normalizeFantasyTeamAfterTrade(
        toTeam,
        nextToRoster,
        isSoccerLeague,
      );

      if (isSoccerLeague) {
        const rawDraftDate =
          league.draftDateTime || league.draftAt || league.draftTime;
        const draftDateMs = timestampToMillis(rawDraftDate);
        if (draftDateMs) {
          const roundCount =
            Number.parseInt(`${league.roundCount || "1"}`, 10) || 1;
          const leagueData = await fetchKLeagueData();
          const rawFixtures = Array.isArray(leagueData && leagueData.fixtures)
            ? leagueData.fixtures
            : [];
          const lockedClubs = lockedClubsForCurrentRound({
            draftDateMs,
            roundCount,
            rawFixtures,
            nowMs: Date.now(),
          });
          validateLockedFantasyRoster({
            existingTeam: fromTeam,
            nextRoster: nextFromTeam.roster,
            nextStarting: nextFromTeam.starting,
            nextBench: nextFromTeam.bench,
            nextCaptainName: nextFromTeam.captainName,
            nextViceCaptainName: nextFromTeam.viceCaptainName,
            nextCaptainPlayerId: nextFromTeam.captainPlayerId,
            nextViceCaptainPlayerId: nextFromTeam.viceCaptainPlayerId,
            lockedClubs,
            normalizeClub: (value) =>
              canonicalKLeagueClub(kLeagueDisplayTeamName(value)),
          });
          validateLockedFantasyRoster({
            existingTeam: toTeam,
            nextRoster: nextToTeam.roster,
            nextStarting: nextToTeam.starting,
            nextBench: nextToTeam.bench,
            nextCaptainName: nextToTeam.captainName,
            nextViceCaptainName: nextToTeam.viceCaptainName,
            nextCaptainPlayerId: nextToTeam.captainPlayerId,
            nextViceCaptainPlayerId: nextToTeam.viceCaptainPlayerId,
            lockedClubs,
            normalizeClub: (value) =>
              canonicalKLeagueClub(kLeagueDisplayTeamName(value)),
          });
        }
      } else {
        const rawDraftDate =
          league.draftDateTime || league.draftAt || league.draftTime;
        const draftDateMs = timestampToMillis(rawDraftDate);
        if (draftDateMs) {
          const roundCount =
            Number.parseInt(`${league.roundCount || "1"}`, 10) || 1;
          const leagueData = await fetchKboLeagueData();
          const rawMatches = Array.isArray(leagueData && leagueData.matches)
            ? leagueData.matches
            : [];
          const lockedClubs = lockedKboClubsForCurrentRound({
            draftDateMs,
            roundCount,
            rawMatches,
            nowMs: Date.now(),
          });
          validateLockedFantasyRoster({
            existingTeam: fromTeam,
            nextRoster: nextFromTeam.roster,
            nextStarting: nextFromTeam.starting,
            nextBench: nextFromTeam.bench,
            nextCaptainName: nextFromTeam.captainName,
            nextViceCaptainName: nextFromTeam.viceCaptainName,
            nextCaptainPlayerId: nextFromTeam.captainPlayerId,
            nextViceCaptainPlayerId: nextFromTeam.viceCaptainPlayerId,
            lockedClubs,
            normalizeClub: (value) => normalizeKboTeamName(value),
          });
          validateLockedFantasyRoster({
            existingTeam: toTeam,
            nextRoster: nextToTeam.roster,
            nextStarting: nextToTeam.starting,
            nextBench: nextToTeam.bench,
            nextCaptainName: nextToTeam.captainName,
            nextViceCaptainName: nextToTeam.viceCaptainName,
            nextCaptainPlayerId: nextToTeam.captainPlayerId,
            nextViceCaptainPlayerId: nextToTeam.viceCaptainPlayerId,
            lockedClubs,
            normalizeClub: (value) => normalizeKboTeamName(value),
          });
        }
      }

      const nextFromKboRoundScoreStates = sanitizeKboRoundScoreStates(
        rawKboRoundScoreStatesByTeam[fromUid] ||
          rawKboRoundScoreStatesByTeam[`${trade.fromTeamName || ""}`],
      );
      const nextToKboRoundScoreStates = sanitizeKboRoundScoreStates(
        rawKboRoundScoreStatesByTeam[toUid] ||
          rawKboRoundScoreStatesByTeam[`${trade.toTeamName || ""}`],
      );

      fantasyTeams[fromIndex] = {
        ...nextFromTeam,
        ...(nextFromKboRoundScoreStates.length
          ? { kboRoundScoreStates: nextFromKboRoundScoreStates }
          : {}),
      };
      fantasyTeams[toIndex] = {
        ...nextToTeam,
        ...(nextToKboRoundScoreStates.length
          ? { kboRoundScoreStates: nextToKboRoundScoreStates }
          : {}),
      };
      transaction.update(leagueRef, {
        fantasyTeams,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(tradeRef, updatePayload);
      return {
        requestId,
        status: "accepted",
        leagueId,
        fantasyTeams,
      };
    });
  },
);

exports.notifyTradeRequestCreated = onDocumentCreated(
  "tradeRequests/{requestId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const trade = snapshot.data() || {};
    const requestId = `${event.params.requestId || ""}`.trim();
    const toUid = `${trade.toUid || ""}`.trim();
    const fromTeamName = `${trade.fromTeamName || "상대 팀"}`.trim();
    const leagueId = `${trade.leagueId || ""}`.trim();
    const leagueName = `${trade.leagueName || "LeagueIt"}`.trim();
    if (!requestId || !toUid) return;

    const eventId = `trade_request:${requestId}`;
    const claimed = await claimPushEvent(eventId, {
      kind: "trade_request",
      leagueId,
      requestId,
      toUid,
    });
    if (!claimed) return;

    await sendPushNotificationToUids({
      uids: [toUid],
      title: `${leagueName} 트레이드 요청🔄`,
      body: `${fromTeamName}에서 트레이드 요청을 보냈습니다.`,
      eventId,
      data: {
        type: "trade_request",
        leagueId,
        requestId,
        leagueName,
      },
    });
  },
);

async function dispatchFantasyTimingNotificationsForLeague({
  data,
  leagueId,
  leagueName,
  members,
  nowMs,
  rawFixtures,
  rawMatches,
}) {
  const draftDateMs = timestampToMillis(
    data.draftDateTime || data.draftAt || data.draftTime,
  );
  if (draftDateMs) {
    const draftLeadMs = draftDateMs - nowMs;
    if (draftLeadMs > 0 && draftLeadMs <= 30 * 60 * 1000) {
      const draftEventId = `draft_soon:${leagueId}:${draftDateMs}`;
      const claimed = await claimPushEvent(draftEventId, {
        kind: "draft_soon",
        leagueId,
        draftDateMs,
      });
      if (claimed) {
        await sendPushNotificationToUids({
          uids: members,
          title: "드래프트 시작 30분 전⏳",
          body: `${leagueName} 드래프트가 30분 뒤에 시작됩니다.`,
          eventId: draftEventId,
          data: {
            type: "draft_soon",
            leagueId,
            leagueName,
          },
        });
      }
    }
  }

  if (!draftDateMs || data.fantasyReady !== true) return;

  const sport = `${data.sport || "soccer"}`.trim().toLowerCase();
  const roundCount = Number.parseInt(`${data.roundCount || "1"}`, 10) || 1;
  const fantasyTeams = Array.isArray(data.fantasyTeams) ? data.fantasyTeams : [];
  const draftOrder = Array.isArray(data.draftOrder) ? data.draftOrder : [];
  const lockState =
    sport === "baseball" ?
      kboRosterLockPushState({
        draftDateMs,
        roundCount,
        rawMatches,
        nowMs,
      }) :
      soccerRosterLockPushState({
        draftDateMs,
        roundCount,
        rawFixtures,
        nowMs,
      });
  const rosterTimingStateId = `roster_timing:${leagueId}`;
  const previousRosterTimingState = await loadPushState(rosterTimingStateId);
  const previousRosterLocked = previousRosterTimingState &&
    previousRosterTimingState.locked === true;
  const previousRosterRound =
    Number(previousRosterTimingState && previousRosterTimingState.round) || 0;
  const previousRosterLockStartsAtMs =
    Number(previousRosterTimingState && previousRosterTimingState.lockStartsAtMs) || 0;

  let currentRosterLocked = lockState.phase === "locked";
  if (sport === "baseball") {
    currentRosterLocked = lockedKboClubsForCurrentRound({
      draftDateMs,
      roundCount,
      rawMatches,
      nowMs,
    }).size > 0;
  }

  if (sport === "baseball") {
    const kickoffGroups = groupTodayKboMatchesByKickoff({
      draftDateMs,
      roundCount,
      rawMatches,
      nowMs,
    });
    for (const group of kickoffGroups) {
      const clubs = group && group.clubs instanceof Set ? group.clubs : new Set();
      if (!clubs.size) continue;

      const lockLeadMs = Number(group.kickoffMs) - nowMs;
      if (lockLeadMs > 0 && lockLeadMs <= 30 * 60 * 1000) {
        const eventId =
          `roster_lock_soon:${leagueId}:${lockState.round}:${group.kickoffMs}`;
        const claimed = await claimPushEvent(eventId, {
          kind: "roster_lock_soon",
          leagueId,
          round: lockState.round,
          lockStartsAtMs: group.kickoffMs,
          clubs: Array.from(clubs),
        });
        if (claimed) {
          await sendKboRosterTimingPushToMembers({
            members,
            fantasyTeams,
            draftOrder,
            leagueId,
            leagueName,
            round: lockState.round,
            title: "로스터 잠금 예정🔒",
            type: "roster_lock_soon",
            eventId,
            clubs,
            isSoon: true,
          });
        }
      }

      const justLocked =
        nowMs >= Number(group.kickoffMs) &&
        nowMs - Number(group.kickoffMs) <= PUSH_EVENT_WINDOW_MS;
      if (!justLocked) continue;
      const eventId = `roster_lock:${leagueId}:${lockState.round}:${group.kickoffMs}`;
      const claimed = await claimPushEvent(eventId, {
        kind: "roster_lock",
        leagueId,
        round: lockState.round,
        lockStartsAtMs: group.kickoffMs,
        clubs: Array.from(clubs),
      });
      if (!claimed) continue;
      await sendKboRosterTimingPushToMembers({
        members,
        fantasyTeams,
        draftOrder,
        leagueId,
        leagueName,
        round: lockState.round,
        title: "로스터 잠금🔒",
        type: "roster_lock",
        eventId,
        clubs,
        isSoon: false,
      });
    }
  } else if (Number.isFinite(lockState.lockStartsAtMs)) {
    const lockLeadMs = lockState.lockStartsAtMs - nowMs;
    if (lockLeadMs > 0 && lockLeadMs <= 30 * 60 * 1000) {
      const eventId =
        `roster_lock_soon:${leagueId}:${lockState.round}:${lockState.lockStartsAtMs}`;
      const claimed = await claimPushEvent(eventId, {
        kind: "roster_lock_soon",
        leagueId,
        round: lockState.round,
        lockStartsAtMs: lockState.lockStartsAtMs,
      });
      if (claimed) {
        await sendPushNotificationToUids({
          uids: members,
          title: "로스터 잠금 예정🔒",
          body: `${leagueName} 로스터가 30분 내 잠깁니다.`,
          eventId,
          data: {
            type: "roster_lock_soon",
            leagueId,
            round: `${lockState.round}`,
            leagueName,
          },
        });
      }
    }
  }

  if (
    sport !== "baseball" &&
    currentRosterLocked &&
    (previousRosterRound !== lockState.round || !previousRosterLocked) &&
    Number.isFinite(lockState.lockStartsAtMs) &&
    nowMs >= lockState.lockStartsAtMs &&
    nowMs - lockState.lockStartsAtMs <= PUSH_EVENT_WINDOW_MS
  ) {
    const eventId =
      `roster_lock:${leagueId}:${lockState.round}:${lockState.lockStartsAtMs}`;
    const claimed = await claimPushEvent(eventId, {
      kind: "roster_lock",
      leagueId,
      round: lockState.round,
      lockStartsAtMs: lockState.lockStartsAtMs,
    });
    if (claimed) {
      await sendPushNotificationToUids({
        uids: members,
        title: "로스터 잠금🔒",
        body: `${leagueName} 로스터가 잠겼습니다.`,
        eventId,
        data: {
          type: "roster_lock",
          leagueId,
          round: `${lockState.round}`,
          leagueName,
        },
      });
    }
  }

  if (!currentRosterLocked && previousRosterLocked) {
    const unlockAnchorMs =
      previousRosterLockStartsAtMs ||
      (Number.isFinite(lockState.unlocksAtMs) ? lockState.unlocksAtMs : nowMs);
    const eventId =
      `roster_unlock:${leagueId}:${Math.max(previousRosterRound, lockState.round, 1)}:${unlockAnchorMs}`;
    const claimed = await claimPushEvent(eventId, {
      kind: "roster_unlock",
      leagueId,
      round: Math.max(previousRosterRound, lockState.round, 1),
      unlocksAtMs: Number.isFinite(lockState.unlocksAtMs) ?
        lockState.unlocksAtMs :
        null,
    });
    if (claimed) {
      await sendPushNotificationToUids({
        uids: members,
        title: "로스터 잠금 해제🔓",
        body: `${leagueName} 로스터 잠금이 해제되었습니다.`,
        eventId,
        data: {
          type: "roster_unlock",
          leagueId,
          round: `${Math.max(previousRosterRound, lockState.round, 1)}`,
          leagueName,
        },
      });
    }
  }

  await writePushState(rosterTimingStateId, {
    leagueId,
    sport,
    round: lockState.round,
    locked: currentRosterLocked,
    phase: lockState.phase,
    lockStartsAtMs: Number.isFinite(lockState.lockStartsAtMs) ?
      lockState.lockStartsAtMs :
      null,
    unlocksAtMs: Number.isFinite(lockState.unlocksAtMs) ?
      lockState.unlocksAtMs :
      null,
  });
}

exports.dispatchFantasyTimingPushNotifications = onSchedule(
  {
    schedule: "* * * * *",
    timeZone: "Asia/Seoul",
    timeoutSeconds: 180,
    memory: "512MiB",
    secrets: [
      "API_SPORTS_KEY",
      "DSG_CLIENT",
      "DSG_USERNAME",
      "DSG_PASSWORD",
      "DSG_AUTHKEY",
    ],
  },
  async () => {
    const leaguesSnapshot = await db.collection("leagues").get();
    if (leaguesSnapshot.empty) return;

    const leagueDocs = leaguesSnapshot.docs;
    const nowMs = Date.now();
    const shouldEvaluateSoccer = leagueDocs.some((doc) => {
      const data = doc.data() || {};
      const sport = `${data.sport || "soccer"}`.trim().toLowerCase();
      return sport === "soccer" && data.fantasyReady === true;
    });
    const shouldEvaluateBaseball = leagueDocs.some((doc) => {
      const data = doc.data() || {};
      const sport = `${data.sport || "soccer"}`.trim().toLowerCase();
      return sport === "baseball" && data.fantasyReady === true;
    });

    const kLeagueData = shouldEvaluateSoccer ? await fetchKLeagueData() : null;
    const rawFixtures =
      Array.isArray(kLeagueData && kLeagueData.fixtures) ?
        kLeagueData.fixtures :
        [];
    const kboLeagueData = shouldEvaluateBaseball ?
      await fetchKboLeagueData() :
      null;
    const rawMatches =
      Array.isArray(kboLeagueData && kboLeagueData.matches) ?
        kboLeagueData.matches :
        [];

    for (const doc of leagueDocs) {
      const data = doc.data() || {};
      const leagueId = doc.id;
      const leagueName = `${data.name || "LeagueIt"}`.trim();
      const members = [...new Set((Array.isArray(data.members) ? data.members : [])
        .map((uid) => `${uid || ""}`.trim())
        .filter(Boolean))];
      if (!members.length) continue;

      await dispatchFantasyTimingNotificationsForLeague({
        data,
        leagueId,
        leagueName,
        members,
        nowMs,
        rawFixtures,
        rawMatches,
      });
    }
  },
);

exports.dispatchFantasyPushNotifications = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Asia/Seoul",
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: [
      "API_SPORTS_KEY",
      "DSG_CLIENT",
      "DSG_USERNAME",
      "DSG_PASSWORD",
      "DSG_AUTHKEY",
    ],
  },
  async () => {
    const leaguesSnapshot = await db.collection("leagues").get();
    if (leaguesSnapshot.empty) return;

    const leagueDocs = leaguesSnapshot.docs;
    const nowMs = Date.now();
    const shouldEvaluateSoccer = leagueDocs.some((doc) => {
      const data = doc.data() || {};
      const sport = `${data.sport || "soccer"}`.trim().toLowerCase();
      return sport === "soccer" && data.fantasyReady === true;
    });
    const shouldEvaluateBaseball = leagueDocs.some((doc) => {
      const data = doc.data() || {};
      const sport = `${data.sport || "soccer"}`.trim().toLowerCase();
      return sport === "baseball" && data.fantasyReady === true;
    });

    const kLeagueData = shouldEvaluateSoccer ? await fetchKLeagueData() : null;
    const rawFixtures =
      Array.isArray(kLeagueData && kLeagueData.fixtures) ?
        kLeagueData.fixtures :
        [];
    const kboLeagueData = shouldEvaluateBaseball ?
      await fetchKboLeagueData() :
      null;
    const rawMatches =
      Array.isArray(kboLeagueData && kboLeagueData.matches) ?
        kboLeagueData.matches :
        [];

    for (const doc of leagueDocs) {
      const data = doc.data() || {};
      const leagueId = doc.id;
      const leagueName = `${data.name || "LeagueIt"}`.trim();
      const members = [...new Set((Array.isArray(data.members) ? data.members : [])
        .map((uid) => `${uid || ""}`.trim())
        .filter(Boolean))];
      if (!members.length) continue;
      await dispatchFantasyTimingNotificationsForLeague({
        data,
        leagueId,
        leagueName,
        members,
        nowMs,
        rawFixtures,
        rawMatches,
      });

      const draftDateMs = timestampToMillis(
        data.draftDateTime || data.draftAt || data.draftTime,
      );
      if (!draftDateMs || data.fantasyReady !== true) continue;

      const sport = `${data.sport || "soccer"}`.trim().toLowerCase();
      const fantasyTeams = activeFantasyTeamsForMembers(
        data.fantasyTeams,
        members,
        data.draftOrder,
      );

      if (sport === "soccer" && fantasyTeams.length) {
        await maybeDispatchSoccerGoalPush({
          leagueId,
          leagueName,
          fantasyTeams,
          draftDateMs,
          roundCount: Number.parseInt(`${data.roundCount || "1"}`, 10) || 1,
          rawFixtures,
          nowMs,
        });
      }

      if (sport === "baseball" && fantasyTeams.length) {
        await maybeDispatchBaseballFptsPush({
          leagueId,
          leagueName,
          fantasyTeams,
          draftDateMs,
          roundCount: Number.parseInt(`${data.roundCount || "1"}`, 10) || 1,
          kboLeagueData,
          rawMatches,
          nowMs,
        });
      }
    }
  },
);

function sanitizeWeeklyLeaderSnapshots(value) {
  const items = Array.isArray(value) ? value : [];
  return items
    .map((item) => {
      const round = Number(item && item.round);
      const leaders = Array.isArray(item && item.leaders) ? item.leaders : [];
      return {
        round: Number.isInteger(round) && round > 0 ? round : 0,
        leaders: leaders
          .slice(0, 3)
          .map((leader) => ({
            name: `${(leader && leader.name) || ""}`.trim(),
            position: `${(leader && leader.position) || ""}`.trim(),
            club: `${(leader && leader.club) || ""}`.trim(),
            points: Number(leader && leader.points) || 0,
          }))
          .filter((leader) => leader.name && leader.position && leader.club),
      };
    })
    .filter((item) => item.round > 0 && item.leaders.length > 0)
    .sort((a, b) => b.round - a.round);
}

exports.getKLeagueWeeklyLeaderSnapshots = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const leagueId = `${(request.data && request.data.leagueId) || ""}`.trim();
  if (!leagueId) {
    throw new HttpsError("invalid-argument", "leagueId is required");
  }

  const leagueRef = db.collection("leagues").doc(leagueId);
  const snapshot = await leagueRef.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "League not found");
  }
  const data = snapshot.data() || {};
  const members = Array.isArray(data.members) ? data.members : [];
  if (!members.includes(uid)) {
    throw new HttpsError("permission-denied", "Not a league member");
  }

  return {
    leagueId,
    snapshots: sanitizeWeeklyLeaderSnapshots(data.kLeagueWeeklyLeaderSnapshots),
  };
});

exports.saveKLeagueWeeklyLeaderSnapshots = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const leagueId = `${(request.data && request.data.leagueId) || ""}`.trim();
  if (!leagueId) {
    throw new HttpsError("invalid-argument", "leagueId is required");
  }

  const snapshots = sanitizeWeeklyLeaderSnapshots(
    request.data && request.data.snapshots,
  );

  const leagueRef = db.collection("leagues").doc(leagueId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(leagueRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "League not found");
    }
    const data = snapshot.data() || {};
    const members = Array.isArray(data.members) ? data.members : [];
    if (!members.includes(uid)) {
      throw new HttpsError("permission-denied", "Not a league member");
    }

    transaction.update(leagueRef, {
      kLeagueWeeklyLeaderSnapshots: snapshots,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      leagueId,
      snapshots,
    };
  });
});

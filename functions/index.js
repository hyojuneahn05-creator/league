const { onRequest } = require("firebase-functions/v2/https");
const axios = require("axios");

const SEASON_YEAR = 2026;
const SEASON_START = new Date("2026-02-28T00:00:00+09:00");

exports.getLeagueStandings = onRequest(
  { secrets: ["API_SPORTS_KEY"] },
  async (req, res) => {
    try {
      const now = new Date();

      // 🏆 Standings API
      const standingsRes = await axios.get(
        `https://v3.football.api-sports.io/standings?league=292&season=${SEASON_YEAR}`,
        {
          headers: {
            "x-apisports-key": process.env.API_SPORTS_KEY,
          },
        }
      );

      const standings =
        standingsRes.data.response?.[0]?.league?.standings?.[0] ?? [];

      // 📅 Fixtures API (전체 시즌 일정)
      const fixturesRes = await axios.get(
        `https://v3.football.api-sports.io/fixtures?league=292&season=${SEASON_YEAR}`,
        {
          headers: {
            "x-apisports-key": process.env.API_SPORTS_KEY,
          },
        }
      );

      const fixtures = fixturesRes.data.response ?? [];

      // 🧊 시즌 시작 전이면 standings만 0으로
      let normalizedStandings = standings;

      if (now < SEASON_START) {
        normalizedStandings = standings.map((team) => ({
          ...team,
          points: 0,
          goalsDiff: 0,
          all: {
            ...team.all,
            played: 0,
          },
        }));
      }

      res.json({
        standings: normalizedStandings,
        fixtures: fixtures,
      });
    } catch (error) {
      console.error(error.response?.data || error.message);
      res.status(500).send("Error fetching data");
    }
  }
);
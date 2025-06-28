const pool = require('../db');

async function getNews() {
  const res = await pool.query('SELECT content FROM news LIMIT 1');
  return res.rows[0]?.content || '';
}

async function setNews(content) {
  await pool.query('UPDATE news SET content = $1', [content]);
}

module.exports = { getNews, setNews };

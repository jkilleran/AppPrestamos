const pool = require('../db');

async function getNews() {
  const res = await pool.query('SELECT content, extra_text, image_url, pdf_url, title FROM news LIMIT 1');
  const row = res.rows[0] || {};
  return {
    content: row.content || '',
    extraText: row.extra_text || '',
    imageUrl: row.image_url || '',
    pdfUrl: row.pdf_url || '',
    title: row.title || 'Novedades del Administrador'
  };
}

async function setNews(content, extraText, imageUrl, pdfUrl, title) {
  await pool.query(
    'UPDATE news SET content = $1, extra_text = $2, image_url = $3, pdf_url = $4, title = $5',
    [content, extraText, imageUrl, pdfUrl, title]
  );
}

module.exports = { getNews, setNews };

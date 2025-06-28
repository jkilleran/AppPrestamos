const { getNews, setNews } = require('../models/news.model');

async function getNewsController(req, res) {
  const news = await getNews();
  res.json(news);
}

async function setNewsController(req, res) {
  // Solo admin
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'No autorizado' });
  }
  const { content, extraText, imageUrl, pdfUrl, title } = req.body;
  if (!content) return res.status(400).json({ error: 'Falta el contenido' });
  await setNews(content, extraText, imageUrl, pdfUrl, title);
  res.json({ ok: true });
}

module.exports = { getNewsController, setNewsController };

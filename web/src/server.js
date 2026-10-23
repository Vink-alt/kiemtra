const express = require('express');
const session = require('express-session');
const path = require('path');
const routes = require('./routes');
const { attachUser, csrfProtection } = require('./middleware/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// Hardening: An header X-Powered-By
app.disable('x-powered-by');

app.set('trust proxy', 1);
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '../views'));

app.use(express.static(path.join(__dirname, '../public')));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));
app.use(express.json({ limit: '2mb' }));

app.use(
  session({
    secret: process.env.SESSION_SECRET || 'fleet_default_secret_devops_2026',
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: 'strict',
      secure: true,
      maxAge: 24 * 60 * 60 * 1000,
    },
  })
);

app.use(attachUser);
app.use(csrfProtection);

app.use('/', routes);

app.use((req, res) => {
  res.status(404).render('errors/404', { title: '404 - Không tìm thấy trang' });
});

app.use((err, req, res, next) => {
  console.error('[SERVER ERROR]', err);
  if (err.code === 'LIMIT_FILE_SIZE') {
    if (req.session) req.session.errorMsg = 'Kích thước tệp vượt quá giới hạn cho phép (tối đa 2 MB)!';
    return res.redirect(req.headers.referer || '/vehicles');
  }
  if (err.message && err.message.includes('Chỉ chấp nhận tệp ảnh')) {
    if (req.session) req.session.errorMsg = err.message;
    return res.redirect(req.headers.referer || '/vehicles');
  }
  res.status(500).render('errors/500', {
    title: '500 - Lỗi máy chủ',
    error: err.message || 'Đã có lỗi không mong muốn xảy ra.',
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[FLEET APP] Server listening on port ${PORT}`);
});

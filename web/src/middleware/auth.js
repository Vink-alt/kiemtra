const crypto = require('crypto');

function getClientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }
  return req.socket.remoteAddress || req.ip || 'unknown';
}

function attachUser(req, res, next) {
  res.locals.user = req.session ? req.session.user : null;
  res.locals.currentPath = req.path;
  res.locals.successMsg = (req.session && req.session.successMsg) || null;
  res.locals.errorMsg = (req.session && req.session.errorMsg) || null;
  if (req.session) {
    delete req.session.successMsg;
    delete req.session.errorMsg;
  }
  next();
}

function csrfProtection(req, res, next) {
  if (!req.session.csrfToken) {
    req.session.csrfToken = crypto.randomBytes(32).toString('hex');
  }
  res.locals.csrfToken = req.session.csrfToken;

  // Skip CSRF check for GET, HEAD, OPTIONS and /health
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method) || req.path === '/health') {
    return next();
  }

  // Check CSRF token from body, query or header
  const token = (req.body && req.body._csrf) || (req.query && req.query._csrf) || req.headers['x-csrf-token'];
  if (!token || token !== req.session.csrfToken) {
    return res.status(403).render('errors/403', {
      title: '403 - Lỗi bảo mật CSRF',
      message: 'Phiên làm việc hoặc CSRF Token không hợp lệ. Vui lòng tải lại trang và thử lại.',
    });
  }
  next();
}

function requireAuth(req, res, next) {
  if (!req.session || !req.session.user) {
    if (req.session) req.session.returnTo = req.originalUrl;
    return res.redirect('/login');
  }
  next();
}

function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.session || !req.session.user) {
      if (req.session) req.session.returnTo = req.originalUrl;
      return res.redirect('/login');
    }
    if (!allowedRoles.includes(req.session.user.role)) {
      return res.status(403).render('errors/403', {
        title: '403 - Truy cập bị từ chối',
        message: 'Bạn không có quyền thực hiện hành động hoặc truy cập trang này.',
      });
    }
    next();
  };
}

module.exports = {
  getClientIp,
  attachUser,
  csrfProtection,
  requireAuth,
  requireRole,
};

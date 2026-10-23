const bcrypt = require('bcryptjs');
const db = require('../config/db');
const { getClientIp } = require('../middleware/auth');

exports.getLogin = (req, res) => {
  if (req.session.user) {
    return res.redirect('/vehicles');
  }
  res.render('login', { title: 'Đăng nhập - Quản lý Đội xe' });
};

exports.postLogin = async (req, res) => {
  const ip = getClientIp(req);
  const { username, password } = req.body;

  if (!username || !password) {
    console.log(`LOGIN_FAILED ip=${ip} user=${username || 'none'} reason=unknown_user`);
    req.session.errorMsg = 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu!';
    return res.redirect('/login');
  }

  try {
    const userRes = await db.query(
      `SELECT u.*, d.id as driver_id 
       FROM users u 
       LEFT JOIN drivers d ON u.id = d.user_id 
       WHERE u.username = $1`,
      [username.trim()]
    );

    if (userRes.rows.length === 0) {
      console.log(`LOGIN_FAILED ip=${ip} user=${username} reason=unknown_user`);
      req.session.errorMsg = 'Tài khoản hoặc mật khẩu không chính xác!';
      return res.redirect('/login');
    }

    const user = userRes.rows[0];

    if (!user.is_active) {
      console.log(`LOGIN_FAILED ip=${ip} user=${username} reason=inactive`);
      req.session.errorMsg = 'Tài khoản này hiện đang bị khóa. Vui lòng liên hệ quản trị viên!';
      return res.redirect('/login');
    }

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      console.log(`LOGIN_FAILED ip=${ip} user=${username} reason=wrong_password`);
      req.session.errorMsg = 'Tài khoản hoặc mật khẩu không chính xác!';
      return res.redirect('/login');
    }

    // Success
    console.log(`LOGIN_SUCCESS ip=${ip} user=${username}`);
    req.session.user = {
      id: user.id,
      username: user.username,
      full_name: user.full_name,
      role: user.role,
      driver_id: user.driver_id,
      email: user.email,
    };

    const targetUrl = req.session.returnTo || (user.role === 'driver' ? '/trips/driver' : '/vehicles');
    delete req.session.returnTo;
    return res.redirect(targetUrl);
  } catch (err) {
    console.error('[AUTH] Login error:', err);
    req.session.errorMsg = 'Có lỗi xảy ra trong quá trình đăng nhập. Vui lòng thử lại!';
    return res.redirect('/login');
  }
};

exports.logout = (req, res) => {
  req.session.destroy(() => {
    res.redirect('/login');
  });
};

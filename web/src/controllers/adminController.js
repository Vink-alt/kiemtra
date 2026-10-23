const bcrypt = require('bcryptjs');
const db = require('../config/db');

// --- VEHICLE TYPES ---
exports.listTypes = async (req, res) => {
  try {
    const typesRes = await db.query('SELECT * FROM vehicle_types ORDER BY sort_order ASC, id ASC');
    res.render('admin/vehicle_types', {
      title: 'Quản lý Loại xe - Admin',
      types: typesRes.rows,
    });
  } catch (err) {
    console.error('[ADMIN] List types error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.postCreateType = async (req, res) => {
  const { name, sort_order } = req.body;
  if (!name || !name.trim()) {
    req.session.errorMsg = 'Tên loại xe không được để trống!';
    return res.redirect('/admin/vehicle-types');
  }
  try {
    await db.query(
      'INSERT INTO vehicle_types (name, sort_order) VALUES ($1, $2)',
      [name.trim(), parseInt(sort_order) || 0]
    );
    req.session.successMsg = 'Đã thêm loại xe mới thành công!';
    res.redirect('/admin/vehicle-types');
  } catch (err) {
    console.error('[ADMIN] Create type error:', err);
    req.session.errorMsg = 'Lỗi khi tạo loại xe (có thể trùng tên)!';
    res.redirect('/admin/vehicle-types');
  }
};

// --- VEHICLES CRUD & RETIRE & UPLOAD ---
exports.getCreateVehicle = async (req, res) => {
  try {
    const typesRes = await db.query('SELECT * FROM vehicle_types ORDER BY sort_order ASC');
    res.render('vehicles/form', {
      title: 'Thêm mới Phương tiện - Admin',
      types: typesRes.rows,
      vehicle: null,
    });
  } catch (err) {
    console.error('[ADMIN] Get create vehicle error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.postCreateVehicle = async (req, res) => {
  const { plate_number, vehicle_type_id, make, model, year, vin, fuel_type, seats, odometer_km, status, insurance_expiry, registration_expiry, next_service_km } = req.body;
  
  let image_path = null;
  if (req.file) {
    image_path = `/uploads/${req.file.filename}`;
  } else {
    // Default image based on vehicle type
    const svgMap = { '1': '/images/vehicles/sedan.svg', '2': '/images/vehicles/suv.svg', '3': '/images/vehicles/pickup.svg', '4': '/images/vehicles/truck.svg', '5': '/images/vehicles/van.svg' };
    image_path = svgMap[vehicle_type_id] || '/images/vehicles/sedan.svg';
  }

  const numYear = parseInt(year);
  const numSeats = parseInt(seats);
  const numOdo = parseInt(odometer_km);
  const numNextService = parseInt(next_service_km);

  if (!plate_number || isNaN(numYear) || numYear < 1990 || isNaN(numSeats) || numSeats <= 0 || isNaN(numOdo) || numOdo < 0) {
    req.session.errorMsg = 'Dữ liệu không hợp lệ: Biển số bắt buộc, năm >= 1990, số chỗ > 0, km >= 0!';
    return res.redirect('/vehicles/create');
  }

  try {
    await db.query(
      `INSERT INTO vehicles (plate_number, vehicle_type_id, make, model, year, vin, fuel_type, seats, odometer_km, status, insurance_expiry, registration_expiry, next_service_km, image_path)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
      [plate_number.trim(), vehicle_type_id, make.trim(), model.trim(), numYear, vin ? vin.trim() : null, fuel_type, numSeats, numOdo, status || 'available', insurance_expiry, registration_expiry, numNextService, image_path]
    );

    req.session.successMsg = `Đã thêm xe ${plate_number} thành công!`;
    res.redirect('/vehicles');
  } catch (err) {
    console.error('[ADMIN] Create vehicle error:', err);
    req.session.errorMsg = 'Lỗi khi thêm phương tiện (có thể trùng biển số)!';
    res.redirect('/vehicles/create');
  }
};

exports.postRetireVehicle = async (req, res) => {
  const { id } = req.params;
  try {
    const vRes = await db.query('SELECT * FROM vehicles WHERE id = $1', [id]);
    if (vRes.rows.length === 0) {
      req.session.errorMsg = 'Phương tiện không tồn tại!';
      return res.redirect('/vehicles');
    }
    const vehicle = vRes.rows[0];

    if (vehicle.status === 'in_use') {
      req.session.errorMsg = `Xe ${vehicle.plate_number} đang chạy chuyến (in_use), không thể thanh lý!`;
      return res.redirect(`/vehicles/${id}`);
    }

    await db.query("UPDATE vehicles SET status = 'retired' WHERE id = $1", [id]);
    req.session.successMsg = `Đã chuyển xe ${vehicle.plate_number} sang trạng thái thanh lý (retired)!`;
    res.redirect(`/vehicles/${id}`);
  } catch (err) {
    console.error('[ADMIN] Retire vehicle error:', err);
    req.session.errorMsg = 'Có lỗi xảy ra khi thanh lý phương tiện!';
    res.redirect('/vehicles');
  }
};

// --- USERS MANAGEMENT ---
exports.listUsers = async (req, res) => {
  try {
    const usersRes = await db.query(
      `SELECT u.*, d.license_number, d.license_class, d.license_expiry
       FROM users u
       LEFT JOIN drivers d ON u.id = d.user_id
       ORDER BY u.id ASC`
    );
    res.render('admin/users', {
      title: 'Quản lý Tài khoản - Admin',
      usersList: usersRes.rows,
    });
  } catch (err) {
    console.error('[ADMIN] List users error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.getCreateUser = (req, res) => {
  res.render('admin/user_form', {
    title: 'Tạo Tài khoản mới - Admin',
  });
};

exports.postCreateUser = async (req, res) => {
  const { username, email, password, full_name, phone, role, license_number, license_class, license_expiry } = req.body;

  if (!username || !email || !password || !full_name || !role) {
    req.session.errorMsg = 'Vui lòng điền đầy đủ các thông tin bắt buộc!';
    return res.redirect('/admin/users/create');
  }

  if (role === 'driver' && (!license_number || !license_class || !license_expiry)) {
    req.session.errorMsg = 'Tài xế bắt buộc phải có số bằng lái, hạng và ngày hết hạn!';
    return res.redirect('/admin/users/create');
  }

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const hash = await bcrypt.hash(password, 10);
    const userRes = await client.query(
      `INSERT INTO users (username, email, password_hash, full_name, phone, role, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, true)
       RETURNING id`,
      [username.trim(), email.trim(), hash, full_name.trim(), phone ? phone.trim() : null, role]
    );
    const newUserId = userRes.rows[0].id;

    if (role === 'driver') {
      await client.query(
        `INSERT INTO drivers (user_id, license_number, license_class, license_expiry, phone)
         VALUES ($1, $2, $3, $4, $5)`,
        [newUserId, license_number.trim(), license_class.trim(), license_expiry, phone ? phone.trim() : null]
      );
    }

    await client.query('COMMIT');
    req.session.successMsg = `Đã tạo tài khoản "${username}" thành công!`;
    res.redirect('/admin/users');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[ADMIN] Create user error:', err);
    req.session.errorMsg = 'Lỗi tạo tài khoản (có thể trùng username, email hoặc số bằng lái)!';
    res.redirect('/admin/users/create');
  } finally {
    client.release();
  }
};

exports.postToggleUserStatus = async (req, res) => {
  const { id } = req.params;
  const currentUserId = req.session.user.id;

  if (parseInt(id) === currentUserId) {
    req.session.errorMsg = 'Bạn không được phép tự khóa tài khoản của chính mình!';
    return res.redirect('/admin/users');
  }

  try {
    const userRes = await db.query('SELECT is_active, username FROM users WHERE id = $1', [id]);
    if (userRes.rows.length === 0) {
      req.session.errorMsg = 'Tài khoản không tồn tại!';
      return res.redirect('/admin/users');
    }
    const target = userRes.rows[0];
    const newStatus = !target.is_active;

    await db.query('UPDATE users SET is_active = $1 WHERE id = $2', [newStatus, id]);
    req.session.successMsg = `Đã ${newStatus ? 'mở khóa' : 'khóa'} tài khoản "${target.username}"!`;
    res.redirect('/admin/users');
  } catch (err) {
    console.error('[ADMIN] Toggle user error:', err);
    req.session.errorMsg = 'Có lỗi xảy ra khi đổi trạng thái tài khoản!';
    res.redirect('/admin/users');
  }
};

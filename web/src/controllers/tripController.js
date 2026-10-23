const crypto = require('crypto');
const qrcode = require('qrcode');
const db = require('../config/db');

exports.listTrips = async (req, res) => {
  try {
    const { status, search } = req.query;
    let query = `
      SELECT t.*, v.plate_number, v.make, v.model, u.full_name as driver_name, cu.full_name as creator_name
      FROM trips t
      JOIN vehicles v ON t.vehicle_id = v.id
      JOIN drivers d ON t.driver_id = d.id
      JOIN users u ON d.user_id = u.id
      JOIN users cu ON t.created_by = cu.id
      WHERE 1=1
    `;
    const params = [];
    if (status) {
      params.push(status);
      query += ` AND t.status = $${params.length}`;
    }
    if (search) {
      params.push(`%${search.trim()}%`);
      query += ` AND (t.trip_code ILIKE $${params.length} OR v.plate_number ILIKE $${params.length} OR u.full_name ILIKE $${params.length})`;
    }
    query += ` ORDER BY t.planned_start DESC`;

    const tripsRes = await db.query(query, params);
    res.render('trips/index', {
      title: 'Điều phối Chuyến xe - Quản lý Đội xe',
      trips: tripsRes.rows,
      filters: { status, search },
    });
  } catch (err) {
    console.error('[TRIP] List error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.getCreateTrip = async (req, res) => {
  try {
    // Only available vehicles
    const vehiclesRes = await db.query(
      `SELECT v.*, vt.name as type_name 
       FROM vehicles v
       JOIN vehicle_types vt ON v.vehicle_type_id = vt.id
       WHERE v.status = 'available'
       ORDER BY v.plate_number ASC`
    );

    // Active drivers with valid license
    const driversRes = await db.query(
      `SELECT d.*, u.full_name 
       FROM drivers d
       JOIN users u ON d.user_id = u.id
       WHERE u.is_active = true AND d.license_expiry >= CURRENT_DATE
       ORDER BY u.full_name ASC`
    );

    res.render('trips/create', {
      title: 'Tạo lệnh Điều phối Chuyến xe',
      vehicles: vehiclesRes.rows,
      drivers: driversRes.rows,
    });
  } catch (err) {
    console.error('[TRIP] Get create error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.postCreateTrip = async (req, res) => {
  const { vehicle_id, driver_id, origin, destination, planned_start, planned_end, purpose } = req.body;
  const created_by = req.session.user.id;

  if (!vehicle_id || !driver_id || !origin || !destination || !planned_start || !planned_end) {
    req.session.errorMsg = 'Vui lòng điền đầy đủ các trường bắt buộc!';
    return res.redirect('/trips/create');
  }

  const startDt = new Date(planned_start);
  const endDt = new Date(planned_end);
  if (isNaN(startDt) || isNaN(endDt) || endDt <= startDt) {
    req.session.errorMsg = 'Thời gian dự kiến kết thúc phải sau thời gian dự kiến bắt đầu!';
    return res.redirect('/trips/create');
  }

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    // Lock rows FOR UPDATE to guarantee strict concurrency & prevent double assignment
    const vehicleRes = await client.query(
      'SELECT id, plate_number, status, odometer_km FROM vehicles WHERE id = $1 FOR UPDATE',
      [vehicle_id]
    );
    if (vehicleRes.rows.length === 0) {
      await client.query('ROLLBACK');
      req.session.errorMsg = 'Phương tiện không tồn tại!';
      return res.redirect('/trips/create');
    }
    const vehicle = vehicleRes.rows[0];

    if (vehicle.status === 'maintenance' || vehicle.status === 'retired') {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Xe ${vehicle.plate_number} đang ở trạng thái "${vehicle.status}", không thể điều phối!`;
      return res.redirect('/trips/create');
    }

    const driverRes = await client.query(
      `SELECT d.id, d.license_expiry, u.is_active, u.full_name 
       FROM drivers d 
       JOIN users u ON d.user_id = u.id 
       WHERE d.id = $1 FOR UPDATE`,
      [driver_id]
    );
    if (driverRes.rows.length === 0) {
      await client.query('ROLLBACK');
      req.session.errorMsg = 'Tài xế không tồn tại!';
      return res.redirect('/trips/create');
    }
    const driver = driverRes.rows[0];

    if (!driver.is_active) {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Tài xế ${driver.full_name} đang bị khóa tài khoản!`;
      return res.redirect('/trips/create');
    }

    if (new Date(driver.license_expiry) < endDt) {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Bằng lái của tài xế ${driver.full_name} hết hạn (${new Date(driver.license_expiry).toLocaleDateString('vi-VN')}) trước khi chuyến xe kết thúc!`;
      return res.redirect('/trips/create');
    }

    // Check vehicle schedule overlap in ('planned', 'in_progress')
    const vehicleConflict = await client.query(
      `SELECT trip_code FROM trips 
       WHERE vehicle_id = $1 
         AND status IN ('planned', 'in_progress')
         AND (planned_start < $2 AND planned_end > $3)`,
      [vehicle_id, endDt.toISOString(), startDt.toISOString()]
    );
    if (vehicleConflict.rows.length > 0) {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Xe ${vehicle.plate_number} đã bị trùng lịch với chuyến ${vehicleConflict.rows[0].trip_code}!`;
      return res.redirect('/trips/create');
    }

    // Check driver schedule overlap in ('planned', 'in_progress')
    const driverConflict = await client.query(
      `SELECT trip_code FROM trips 
       WHERE driver_id = $1 
         AND status IN ('planned', 'in_progress')
         AND (planned_start < $2 AND planned_end > $3)`,
      [driver_id, endDt.toISOString(), startDt.toISOString()]
    );
    if (driverConflict.rows.length > 0) {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Tài xế ${driver.full_name} đã bị trùng lịch với chuyến ${driverConflict.rows[0].trip_code}!`;
      return res.redirect('/trips/create');
    }

    // Generate random hard-to-guess trip code
    const dateStr = startDt.toISOString().slice(0, 10).replace(/-/g, '');
    const randCode = crypto.randomBytes(3).toString('hex').toUpperCase();
    const trip_code = `TRP-${dateStr}-${randCode}`;

    await client.query(
      `INSERT INTO trips (trip_code, vehicle_id, driver_id, created_by, status, purpose, origin, destination, planned_start, planned_end)
       VALUES ($1, $2, $3, $4, 'planned', $5, $6, $7, $8, $9)`,
      [trip_code, vehicle_id, driver_id, created_by, purpose || null, origin.trim(), destination.trim(), startDt.toISOString(), endDt.toISOString()]
    );

    await client.query('COMMIT');
    req.session.successMsg = `Đã tạo lệnh điều xe ${trip_code} thành công!`;
    return res.redirect('/trips');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[TRIP] Post create error:', err);
    req.session.errorMsg = 'Có lỗi xảy ra khi tạo chuyến xe: ' + err.message;
    return res.redirect('/trips/create');
  } finally {
    client.release();
  }
};

exports.postCancelTrip = async (req, res) => {
  const { id } = req.params;
  const { cancel_reason } = req.body;

  if (!cancel_reason || !cancel_reason.trim()) {
    req.session.errorMsg = 'Vui lòng cung cấp lý do hủy chuyến!';
    return res.redirect('/trips');
  }

  try {
    const tripRes = await db.query('SELECT * FROM trips WHERE id = $1', [id]);
    if (tripRes.rows.length === 0) {
      req.session.errorMsg = 'Không tìm thấy chuyến xe!';
      return res.redirect('/trips');
    }
    const trip = tripRes.rows[0];
    if (trip.status !== 'planned') {
      req.session.errorMsg = 'Chỉ có thể hủy chuyến xe đang ở trạng thái "Chờ thực hiện (planned)"!';
      return res.redirect('/trips');
    }

    await db.query(
      `UPDATE trips SET status = 'cancelled', cancel_reason = $1 WHERE id = $2`,
      [cancel_reason.trim(), id]
    );

    req.session.successMsg = `Đã hủy chuyến xe ${trip.trip_code} thành công.`;
    res.redirect('/trips');
  } catch (err) {
    console.error('[TRIP] Cancel error:', err);
    req.session.errorMsg = 'Có lỗi xảy ra khi hủy chuyến xe!';
    res.redirect('/trips');
  }
};

exports.getDriverTrips = async (req, res) => {
  try {
    const driver_id = req.session.user.driver_id;
    if (!driver_id) {
      return res.status(403).render('errors/403', {
        title: '403 - Quyền tài xế không hợp lệ',
        message: 'Tài khoản của bạn chưa được liên kết hồ sơ tài xế!',
      });
    }

    const tripsRes = await db.query(
      `SELECT t.*, v.plate_number, v.make, v.model, v.odometer_km as current_vehicle_km
       FROM trips t
       JOIN vehicles v ON t.vehicle_id = v.id
       WHERE t.driver_id = $1
       ORDER BY 
         CASE WHEN t.status = 'in_progress' THEN 1
              WHEN t.status = 'planned' THEN 2
              ELSE 3 END,
         t.planned_start DESC`,
      [driver_id]
    );

    res.render('trips/driver', {
      title: 'Chuyến xe của tôi - Tài xế',
      trips: tripsRes.rows,
    });
  } catch (err) {
    console.error('[TRIP] Driver trips error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.postStartTrip = async (req, res) => {
  const { id } = req.params;
  const { start_odometer } = req.body;
  const user = req.session.user;

  const startKm = parseInt(start_odometer);
  if (isNaN(startKm) || startKm < 0) {
    req.session.errorMsg = 'Số công tơ mét bắt đầu phải là số nguyên dương hợp lệ!';
    return res.redirect('/trips/driver');
  }

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const tripRes = await client.query(
      `SELECT t.*, v.plate_number, v.odometer_km as current_v_km 
       FROM trips t 
       JOIN vehicles v ON t.vehicle_id = v.id 
       WHERE t.id = $1 FOR UPDATE`,
      [id]
    );

    if (tripRes.rows.length === 0) {
      await client.query('ROLLBACK');
      req.session.errorMsg = 'Chuyến xe không tồn tại!';
      return res.redirect('/trips/driver');
    }
    const trip = tripRes.rows[0];

    // Check permission: Driver must own the trip, or dispatcher/admin
    if (user.role === 'driver' && trip.driver_id !== user.driver_id) {
      await client.query('ROLLBACK');
      return res.status(403).render('errors/403', {
        title: '403 - Từ chối truy cập',
        message: 'Bạn không có quyền thao tác trên chuyến xe của người khác!',
      });
    }

    if (trip.status !== 'planned') {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Chuyến xe đang ở trạng thái "${trip.status}", không thể bắt đầu!`;
      return res.redirect('/trips/driver');
    }

    if (startKm < trip.current_v_km) {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Số công tơ mét (${startKm} km) không được nhỏ hơn số km hiện tại của xe (${trip.current_v_km} km)!`;
      return res.redirect('/trips/driver');
    }

    // Update trip
    await client.query(
      `UPDATE trips 
       SET status = 'in_progress', started_at = CURRENT_TIMESTAMP, start_odometer = $1 
       WHERE id = $2`,
      [startKm, id]
    );

    // Update vehicle to in_use and sync odometer if higher
    await client.query(
      `UPDATE vehicles SET status = 'in_use', odometer_km = $1 WHERE id = $2`,
      [startKm, trip.vehicle_id]
    );

    await client.query('COMMIT');

    // Strict logging requirement
    console.log(`TRIP_STATUS_CHANGE trip=${trip.trip_code} vehicle=${trip.plate_number} from=planned to=in_progress by=${user.username}`);

    req.session.successMsg = `Đã bắt đầu chuyến xe ${trip.trip_code}!`;
    return res.redirect('/trips/driver');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[TRIP] Start error:', err);
    req.session.errorMsg = 'Có lỗi xảy ra khi bắt đầu chuyến xe!';
    return res.redirect('/trips/driver');
  } finally {
    client.release();
  }
};

exports.postEndTrip = async (req, res) => {
  const { id } = req.params;
  const { end_odometer } = req.body;
  const user = req.session.user;

  const endKm = parseInt(end_odometer);
  if (isNaN(endKm) || endKm < 0) {
    req.session.errorMsg = 'Số công tơ mét kết thúc phải là số hợp lệ!';
    return res.redirect('/trips/driver');
  }

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const tripRes = await client.query(
      `SELECT t.*, v.plate_number 
       FROM trips t 
       JOIN vehicles v ON t.vehicle_id = v.id 
       WHERE t.id = $1 FOR UPDATE`,
      [id]
    );

    if (tripRes.rows.length === 0) {
      await client.query('ROLLBACK');
      req.session.errorMsg = 'Chuyến xe không tồn tại!';
      return res.redirect('/trips/driver');
    }
    const trip = tripRes.rows[0];

    // Check permission
    if (user.role === 'driver' && trip.driver_id !== user.driver_id) {
      await client.query('ROLLBACK');
      return res.status(403).render('errors/403', {
        title: '403 - Từ chối truy cập',
        message: 'Bạn không có quyền thao tác trên chuyến xe của người khác!',
      });
    }

    if (trip.status !== 'in_progress') {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Chuyến xe không ở trạng thái "Đang thực hiện (in_progress)"!`;
      return res.redirect('/trips/driver');
    }

    if (endKm < trip.start_odometer) {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Số công tơ mét kết thúc (${endKm} km) không được nhỏ hơn số bắt đầu (${trip.start_odometer} km)!`;
      return res.redirect('/trips/driver');
    }

    const distanceKm = endKm - trip.start_odometer;

    // Update trip
    await client.query(
      `UPDATE trips 
       SET status = 'completed', ended_at = CURRENT_TIMESTAMP, end_odometer = $1, distance_km = $2 
       WHERE id = $3`,
      [endKm, distanceKm, id]
    );

    // Update vehicle to available and new odometer
    await client.query(
      `UPDATE vehicles SET status = 'available', odometer_km = $1 WHERE id = $2`,
      [endKm, trip.vehicle_id]
    );

    await client.query('COMMIT');

    // Strict logging requirement
    console.log(`TRIP_STATUS_CHANGE trip=${trip.trip_code} vehicle=${trip.plate_number} from=in_progress to=completed by=${user.username}`);

    req.session.successMsg = `Đã hoàn thành chuyến xe ${trip.trip_code}! Quãng đường: ${distanceKm} km.`;
    return res.redirect('/trips/driver');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[TRIP] End error:', err);
    req.session.errorMsg = 'Có lỗi xảy ra khi kết thúc chuyến xe!';
    return res.redirect('/trips/driver');
  } finally {
    client.release();
  }
};

exports.printDispatchOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const user = req.session.user;

    const tripRes = await db.query(
      `SELECT t.*, v.plate_number, v.make, v.model, v.fuel_type, v.seats,
              u.full_name as driver_name, d.license_number, d.license_class, d.phone as driver_phone,
              cu.full_name as creator_name
       FROM trips t
       JOIN vehicles v ON t.vehicle_id = v.id
       JOIN drivers d ON t.driver_id = d.id
       JOIN users u ON d.user_id = u.id
       JOIN users cu ON t.created_by = cu.id
       WHERE t.id = $1`,
      [id]
    );

    if (tripRes.rows.length === 0) {
      return res.status(404).render('errors/404', { title: '404 - Không tìm thấy lệnh điều xe' });
    }
    const trip = tripRes.rows[0];

    // Anti-IDOR: dispatcher/admin OR assigned driver only!
    if (user.role === 'driver' && trip.driver_id !== user.driver_id) {
      return res.status(403).render('errors/403', {
        title: '403 - Từ chối truy cập',
        message: 'Bạn không có quyền truy cập phiếu lệnh điều xe này!',
      });
    }

    // Generate QR code data URL server-side
    const qrDataUrl = await qrcode.toDataURL(trip.trip_code, {
      width: 180,
      margin: 1,
      color: { dark: '#0f172a', light: '#ffffff' }
    });

    res.render('trips/print', {
      title: `Lệnh điều xe - ${trip.trip_code}`,
      trip,
      qrDataUrl,
    });
  } catch (err) {
    console.error('[TRIP] Print error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

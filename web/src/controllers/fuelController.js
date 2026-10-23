const db = require('../config/db');

exports.listFuel = async (req, res) => {
  try {
    const user = req.session.user;
    let query = `
      SELECT f.*, v.plate_number, v.make, v.model, u.full_name as recorder_name, t.trip_code
      FROM fuel_logs f
      JOIN vehicles v ON f.vehicle_id = v.id
      JOIN users u ON f.recorded_by = u.id
      LEFT JOIN trips t ON f.trip_id = t.id
    `;
    const params = [];
    if (user.role === 'driver') {
      params.push(user.id);
      query += ` WHERE f.recorded_by = $1`;
    }
    query += ` ORDER BY f.filled_at DESC LIMIT 50`;

    const fuelRes = await db.query(query, params);
    res.render('fuel/index', {
      title: 'Quản lý Nhiên liệu - Quản lý Đội xe',
      logs: fuelRes.rows,
    });
  } catch (err) {
    console.error('[FUEL] List error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.getCreateFuel = async (req, res) => {
  try {
    const user = req.session.user;
    let vehiclesRes;
    let tripsRes;

    if (user.role === 'driver') {
      // Only vehicles and trips assigned to this driver
      vehiclesRes = await db.query(
        `SELECT DISTINCT v.id, v.plate_number, v.make, v.model, v.odometer_km
         FROM trips t
         JOIN vehicles v ON t.vehicle_id = v.id
         WHERE t.driver_id = $1 AND t.status IN ('in_progress', 'completed')
         ORDER BY v.plate_number ASC`,
        [user.driver_id]
      );
      tripsRes = await db.query(
        `SELECT id, trip_code, vehicle_id 
         FROM trips 
         WHERE driver_id = $1 AND status IN ('in_progress', 'completed')
         ORDER BY planned_start DESC LIMIT 20`,
        [user.driver_id]
      );
    } else {
      vehiclesRes = await db.query(
        `SELECT id, plate_number, make, model, odometer_km 
         FROM vehicles 
         WHERE status != 'retired' 
         ORDER BY plate_number ASC`
      );
      tripsRes = await db.query(
        `SELECT id, trip_code, vehicle_id 
         FROM trips 
         ORDER BY planned_start DESC LIMIT 30`
      );
    }

    res.render('fuel/create', {
      title: 'Ghi nhận Đổ Nhiên liệu',
      vehicles: vehiclesRes.rows,
      trips: tripsRes.rows,
    });
  } catch (err) {
    console.error('[FUEL] Get create error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.postCreateFuel = async (req, res) => {
  const { vehicle_id, trip_id, filled_at, liters, price_per_liter, odometer_km, station } = req.body;
  const user = req.session.user;

  const numLiters = parseFloat(liters);
  const numPrice = parseFloat(price_per_liter);
  const numOdo = parseInt(odometer_km);

  if (!vehicle_id || isNaN(numLiters) || numLiters <= 0 || isNaN(numPrice) || numPrice < 0 || isNaN(numOdo) || numOdo < 0) {
    req.session.errorMsg = 'Dữ liệu không hợp lệ: Số lít > 0, đơn giá >= 0, số công tơ mét >= 0!';
    return res.redirect('/fuel/create');
  }

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    // Check last odometer of this vehicle
    const vehicleRes = await client.query(
      'SELECT id, plate_number, odometer_km FROM vehicles WHERE id = $1 FOR UPDATE',
      [vehicle_id]
    );
    if (vehicleRes.rows.length === 0) {
      await client.query('ROLLBACK');
      req.session.errorMsg = 'Phương tiện không tồn tại!';
      return res.redirect('/fuel/create');
    }
    const vehicle = vehicleRes.rows[0];

    // Check previous fuel log odometer
    const lastFuelRes = await client.query(
      'SELECT MAX(odometer_km) as max_fuel_odo FROM fuel_logs WHERE vehicle_id = $1',
      [vehicle_id]
    );
    const maxFuelOdo = lastFuelRes.rows[0].max_fuel_odo || 0;
    if (numOdo < maxFuelOdo) {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Số công tơ mét (${numOdo} km) không được nhỏ hơn lần đổ nhiên liệu trước (${maxFuelOdo} km)!`;
      return res.redirect('/fuel/create');
    }

    // Driver authorization check
    if (user.role === 'driver') {
      if (trip_id) {
        const tripCheck = await client.query(
          'SELECT id FROM trips WHERE id = $1 AND driver_id = $2',
          [trip_id, user.driver_id]
        );
        if (tripCheck.rows.length === 0) {
          await client.query('ROLLBACK');
          return res.status(403).render('errors/403', {
            title: '403 - Từ chối truy cập',
            message: 'Tài xế chỉ được ghi nhiên liệu cho chuyến xe của chính mình!',
          });
        }
      }
    }

    const total_cost = Math.round(numLiters * numPrice);
    const fillDate = filled_at ? new Date(filled_at) : new Date();

    await client.query(
      `INSERT INTO fuel_logs (vehicle_id, trip_id, filled_at, liters, price_per_liter, total_cost, odometer_km, station, recorded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [vehicle_id, trip_id || null, fillDate.toISOString(), numLiters, numPrice, total_cost, numOdo, station ? station.trim() : null, user.id]
    );

    // Sync vehicle odometer if this fuel log has higher odometer
    if (numOdo > vehicle.odometer_km) {
      await client.query('UPDATE vehicles SET odometer_km = $1 WHERE id = $2', [numOdo, vehicle_id]);
    }

    await client.query('COMMIT');
    req.session.successMsg = `Đã ghi nhận ${numLiters} lít xăng/dầu cho xe ${vehicle.plate_number} thành công!`;
    return res.redirect('/fuel');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[FUEL] Post create error:', err);
    req.session.errorMsg = 'Có lỗi xảy ra: ' + err.message;
    return res.redirect('/fuel/create');
  } finally {
    client.release();
  }
};

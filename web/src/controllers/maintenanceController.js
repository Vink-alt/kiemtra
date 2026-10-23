const db = require('../config/db');

exports.listMaintenance = async (req, res) => {
  try {
    const { type } = req.query;
    let query = `
      SELECT m.*, v.plate_number, v.make, v.model, u.full_name as tech_name
      FROM maintenance_records m
      JOIN vehicles v ON m.vehicle_id = v.id
      JOIN users u ON m.performed_by = u.id
    `;
    const params = [];
    if (type) {
      params.push(type);
      query += ` WHERE m.type = $1`;
    }
    query += ` ORDER BY m.serviced_at DESC LIMIT 50`;

    const recordsRes = await db.query(query, params);
    res.render('maintenance/index', {
      title: 'Quản lý Bảo dưỡng & Sửa chữa',
      records: recordsRes.rows,
      filters: { type },
    });
  } catch (err) {
    console.error('[MAINT] List error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.getCreateMaintenance = async (req, res) => {
  try {
    const vehiclesRes = await db.query(
      `SELECT id, plate_number, make, model, odometer_km, status 
       FROM vehicles 
       WHERE status != 'retired' 
       ORDER BY plate_number ASC`
    );
    res.render('maintenance/create', {
      title: 'Tạo Phiếu Bảo dưỡng / Sửa chữa',
      vehicles: vehiclesRes.rows,
    });
  } catch (err) {
    console.error('[MAINT] Get create error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.postCreateMaintenance = async (req, res) => {
  const { vehicle_id, type, description, cost, odometer_km, serviced_at, next_due_km, set_maintenance_status } = req.body;
  const user = req.session.user;

  const numCost = parseFloat(cost);
  const numOdo = parseInt(odometer_km);
  const numNextDue = next_due_km ? parseInt(next_due_km) : null;

  if (!vehicle_id || !type || !description || isNaN(numCost) || numCost < 0 || isNaN(numOdo) || numOdo < 0) {
    req.session.errorMsg = 'Vui lòng điền đầy đủ và chính xác thông tin bắt buộc!';
    return res.redirect('/maintenance/create');
  }

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const vehicleRes = await client.query(
      'SELECT id, plate_number, status, odometer_km, next_service_km FROM vehicles WHERE id = $1 FOR UPDATE',
      [vehicle_id]
    );
    if (vehicleRes.rows.length === 0) {
      await client.query('ROLLBACK');
      req.session.errorMsg = 'Phương tiện không tồn tại!';
      return res.redirect('/maintenance/create');
    }
    const vehicle = vehicleRes.rows[0];

    // Cannot maintain vehicle in_use
    if (vehicle.status === 'in_use') {
      await client.query('ROLLBACK');
      req.session.errorMsg = `Xe ${vehicle.plate_number} đang thực hiện chuyến đi (in_use), không thể đưa vào bảo dưỡng!`;
      return res.redirect('/maintenance/create');
    }

    const dateVal = serviced_at ? new Date(serviced_at) : new Date();

    await client.query(
      `INSERT INTO maintenance_records (vehicle_id, type, description, cost, odometer_km, serviced_at, next_due_km, performed_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [vehicle_id, type, description.trim(), numCost, numOdo, dateVal.toISOString().slice(0, 10), numNextDue, user.id]
    );

    // Update vehicle status & next service
    if (set_maintenance_status === 'yes') {
      await client.query("UPDATE vehicles SET status = 'maintenance' WHERE id = $1", [vehicle_id]);
    } else {
      // Completed maintenance: set available and update next_service_km if specified
      let updateSql = "UPDATE vehicles SET status = 'available'";
      const updateParams = [];
      if (numNextDue && numNextDue > vehicle.odometer_km) {
        updateParams.push(numNextDue, vehicle_id);
        updateSql += `, next_service_km = $1 WHERE id = $2`;
      } else {
        updateParams.push(vehicle_id);
        updateSql += ` WHERE id = $1`;
      }
      await client.query(updateSql, updateParams);
    }

    await client.query('COMMIT');
    req.session.successMsg = `Đã lưu hồ sơ bảo dưỡng cho xe ${vehicle.plate_number} thành công!`;
    return res.redirect('/maintenance');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[MAINT] Post create error:', err);
    req.session.errorMsg = 'Có lỗi xảy ra: ' + err.message;
    return res.redirect('/maintenance/create');
  } finally {
    client.release();
  }
};

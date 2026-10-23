const db = require('../config/db');

exports.listVehicles = async (req, res) => {
  try {
    const { type, status, fuel, search, sort = 'plate', order = 'asc', page = 1 } = req.query;
    const limit = 10;
    const offset = (Math.max(1, parseInt(page)) - 1) * limit;

    let query = `
      SELECT v.*, vt.name as type_name 
      FROM vehicles v
      JOIN vehicle_types vt ON v.vehicle_type_id = vt.id
      WHERE 1=1
    `;
    const params = [];

    if (type) {
      params.push(type);
      query += ` AND v.vehicle_type_id = $${params.length}`;
    }
    if (status) {
      params.push(status);
      query += ` AND v.status = $${params.length}`;
    }
    if (fuel) {
      params.push(fuel);
      query += ` AND v.fuel_type = $${params.length}`;
    }
    if (search) {
      params.push(`%${search.trim()}%`);
      query += ` AND (v.plate_number ILIKE $${params.length} OR v.make ILIKE $${params.length} OR v.model ILIKE $${params.length})`;
    }

    // Count total matching
    const countRes = await db.query(query.replace('SELECT v.*, vt.name as type_name', 'SELECT COUNT(*)'), params);
    const totalVehicles = parseInt(countRes.rows[0].count);

    // Sorting
    const sortFieldMap = {
      plate: 'v.plate_number',
      year: 'v.year',
      km: 'v.odometer_km',
      status: 'v.status',
    };
    const sortCol = sortFieldMap[sort] || 'v.plate_number';
    const sortDir = order === 'desc' ? 'DESC' : 'ASC';
    query += ` ORDER BY ${sortCol} ${sortDir} LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const vehiclesRes = await db.query(query, params);
    const typesRes = await db.query('SELECT * FROM vehicle_types ORDER BY sort_order ASC');

    res.render('vehicles/index', {
      title: 'Danh sách Đội xe - Quản lý Đội xe',
      vehicles: vehiclesRes.rows,
      types: typesRes.rows,
      filters: { type, status, fuel, search, sort, order, page: parseInt(page) },
      totalPages: Math.ceil(totalVehicles / limit) || 1,
      totalVehicles,
    });
  } catch (err) {
    console.error('[VEHICLE] List error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

exports.getVehicleDetail = async (req, res) => {
  try {
    const { id } = req.params;
    const vehicleRes = await db.query(
      `SELECT v.*, vt.name as type_name
       FROM vehicles v
       JOIN vehicle_types vt ON v.vehicle_type_id = vt.id
       WHERE v.id = $1`,
      [id]
    );

    if (vehicleRes.rows.length === 0) {
      return res.status(404).render('errors/404', { title: '404 - Không tìm thấy xe' });
    }
    const vehicle = vehicleRes.rows[0];

    // Trips history
    const tripsRes = await db.query(
      `SELECT t.*, u.full_name as driver_name
       FROM trips t
       JOIN drivers d ON t.driver_id = d.id
       JOIN users u ON d.user_id = u.id
       WHERE t.vehicle_id = $1
       ORDER BY t.planned_start DESC LIMIT 10`,
      [id]
    );

    // Maintenance history
    const maintRes = await db.query(
      `SELECT m.*, u.full_name as tech_name
       FROM maintenance_records m
       JOIN users u ON m.performed_by = u.id
       WHERE m.vehicle_id = $1
       ORDER BY m.serviced_at DESC LIMIT 10`,
      [id]
    );

    // Fuel logs
    const fuelRes = await db.query(
      `SELECT f.*, u.full_name as recorder_name
       FROM fuel_logs f
       JOIN users u ON f.recorded_by = u.id
       WHERE f.vehicle_id = $1
       ORDER BY f.filled_at DESC LIMIT 10`,
      [id]
    );

    // Calculate average fuel consumption (liters / 100km)
    // Formula: Total completed trip distance and total fuel in completed trips or fuel log diffs
    const statsRes = await db.query(
      `SELECT 
         COALESCE(SUM(liters), 0) as total_liters,
         COALESCE(MAX(odometer_km) - MIN(odometer_km), 0) as km_span
       FROM fuel_logs WHERE vehicle_id = $1`,
      [id]
    );
    let avgConsumption = null;
    const totalLiters = parseFloat(statsRes.rows[0].total_liters);
    const kmSpan = parseInt(statsRes.rows[0].km_span);
    if (kmSpan > 0 && totalLiters > 0) {
      avgConsumption = ((totalLiters / kmSpan) * 100).toFixed(2);
    }

    res.render('vehicles/detail', {
      title: `Chi tiết xe ${vehicle.plate_number}`,
      vehicle,
      trips: tripsRes.rows,
      maintenance: maintRes.rows,
      fuelLogs: fuelRes.rows,
      avgConsumption,
    });
  } catch (err) {
    console.error('[VEHICLE] Detail error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

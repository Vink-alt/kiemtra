const db = require('../config/db');

exports.getAlerts = async (req, res) => {
  try {
    // 1. Vehicles with service due <= 500 km or overdue
    const serviceAlerts = await db.query(
      `SELECT v.*, vt.name as type_name,
              (v.next_service_km - v.odometer_km) as km_remaining
       FROM vehicles v
       JOIN vehicle_types vt ON v.vehicle_type_id = vt.id
       WHERE v.status != 'retired' AND (v.next_service_km - v.odometer_km) <= 500
       ORDER BY km_remaining ASC`
    );

    // 2. Vehicles with registration or insurance expiry <= 30 days or overdue
    const documentAlerts = await db.query(
      `SELECT v.*, vt.name as type_name,
              (v.registration_expiry - CURRENT_DATE) as reg_days_left,
              (v.insurance_expiry - CURRENT_DATE) as ins_days_left
       FROM vehicles v
       JOIN vehicle_types vt ON v.vehicle_type_id = vt.id
       WHERE v.status != 'retired' 
         AND (
           (v.registration_expiry - CURRENT_DATE) <= 30
           OR (v.insurance_expiry - CURRENT_DATE) <= 30
         )
       ORDER BY LEAST(v.registration_expiry - CURRENT_DATE, v.insurance_expiry - CURRENT_DATE) ASC`
    );

    // 3. Drivers with license expiry <= 30 days or overdue
    const driverAlerts = await db.query(
      `SELECT d.*, u.full_name, u.username, u.is_active,
              (d.license_expiry - CURRENT_DATE) as license_days_left
       FROM drivers d
       JOIN users u ON d.user_id = u.id
       WHERE (d.license_expiry - CURRENT_DATE) <= 30
       ORDER BY license_days_left ASC`
    );

    res.render('alerts/index', {
      title: 'Trung tâm Cảnh báo Hạn - Quản lý Đội xe',
      serviceAlerts: serviceAlerts.rows,
      documentAlerts: documentAlerts.rows,
      driverAlerts: driverAlerts.rows,
    });
  } catch (err) {
    console.error('[ALERT] Error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

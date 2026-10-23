const db = require('../config/db');

exports.getKPI = async (req, res) => {
  try {
    // 1. Total vehicles & status breakdown
    const vehiclesStats = await db.query(
      `SELECT 
         COUNT(*) as total_vehicles,
         COUNT(*) FILTER (WHERE status = 'in_use') as in_use_count,
         COUNT(*) FILTER (WHERE status = 'available') as available_count,
         COUNT(*) FILTER (WHERE status = 'maintenance') as maintenance_count,
         COUNT(*) FILTER (WHERE status = 'retired') as retired_count
       FROM vehicles`
    );
    const vStats = vehiclesStats.rows[0];
    const totalVehicles = parseInt(vStats.total_vehicles);
    const inUsePct = totalVehicles > 0 ? ((parseInt(vStats.in_use_count) / totalVehicles) * 100).toFixed(1) : 0;

    // 2. Alert counts (vehicles + drivers)
    const alertCountRes = await db.query(
      `SELECT 
         (SELECT COUNT(*) FROM vehicles WHERE status != 'retired' AND (next_service_km - odometer_km) <= 500) as service_alerts,
         (SELECT COUNT(*) FROM vehicles WHERE status != 'retired' AND ((registration_expiry - CURRENT_DATE) <= 30 OR (insurance_expiry - CURRENT_DATE) <= 30)) as doc_alerts,
         (SELECT COUNT(*) FROM drivers WHERE (license_expiry - CURRENT_DATE) <= 30) as driver_alerts`
    );
    const alertStats = alertCountRes.rows[0];
    const totalAlerts = parseInt(alertStats.service_alerts) + parseInt(alertStats.doc_alerts) + parseInt(alertStats.driver_alerts);

    // 3. Total km and costs this month
    const monthStats = await db.query(
      `SELECT
         COALESCE((SELECT SUM(distance_km) FROM trips WHERE status = 'completed' AND ended_at >= DATE_TRUNC('month', CURRENT_DATE)), 0) as month_km,
         COALESCE((SELECT SUM(total_cost) FROM fuel_logs WHERE filled_at >= DATE_TRUNC('month', CURRENT_DATE)), 0) as month_fuel_cost,
         COALESCE((SELECT SUM(cost) FROM maintenance_records WHERE serviced_at >= DATE_TRUNC('month', CURRENT_DATE)), 0) as month_maint_cost`
    );
    const mStats = monthStats.rows[0];

    // 4. Top vehicles by odometer
    const topVehicles = await db.query(
      `SELECT v.plate_number, v.make, v.model, v.odometer_km, vt.name as type_name
       FROM vehicles v
       JOIN vehicle_types vt ON v.vehicle_type_id = vt.id
       ORDER BY v.odometer_km DESC LIMIT 5`
    );

    // 5. Fuel consumption and costs per vehicle
    const vehicleFuelStats = await db.query(
      `SELECT 
         v.plate_number, v.make, v.model,
         COALESCE(SUM(f.liters), 0) as total_liters,
         COALESCE(SUM(f.total_cost), 0) as total_cost,
         COUNT(f.id) as fill_count
       FROM vehicles v
       LEFT JOIN fuel_logs f ON v.id = f.vehicle_id
       GROUP BY v.id, v.plate_number, v.make, v.model
       ORDER BY total_cost DESC LIMIT 8`
    );

    res.render('kpi/index', {
      title: 'Báo cáo KPI & Hiệu suất - Quản lý Đội xe',
      vStats,
      inUsePct,
      totalAlerts,
      alertStats,
      mStats,
      topVehicles: topVehicles.rows,
      vehicleFuelStats: vehicleFuelStats.rows,
    });
  } catch (err) {
    console.error('[KPI] Error:', err);
    res.status(500).render('errors/500', { title: '500 - Lỗi máy chủ', error: err.message });
  }
};

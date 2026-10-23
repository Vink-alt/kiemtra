const express = require('express');
const router = express.Router();

const authController = require('../controllers/authController');
const vehicleController = require('../controllers/vehicleController');
const tripController = require('../controllers/tripController');
const fuelController = require('../controllers/fuelController');
const maintenanceController = require('../controllers/maintenanceController');
const alertController = require('../controllers/alertController');
const kpiController = require('../controllers/kpiController');
const adminController = require('../controllers/adminController');

const { requireAuth, requireRole } = require('../middleware/auth');
const upload = require('../middleware/upload');

// 1. Health check (Must respond "OK" with 200)
router.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// 2. Authentication
router.get('/login', authController.getLogin);
router.post('/login', authController.postLogin);
router.get('/logout', authController.logout);
router.post('/logout', authController.logout);

// Root redirect
router.get('/', (req, res) => {
  if (!req.session.user) {
    return res.redirect('/login');
  }
  if (req.session.user.role === 'driver') {
    return res.redirect('/trips/driver');
  }
  res.redirect('/vehicles');
});

// 3. Vehicles (authenticated)
router.get('/vehicles', requireAuth, vehicleController.listVehicles);
router.get('/vehicles/create', requireRole('admin'), adminController.getCreateVehicle);
router.post('/vehicles/create', requireRole('admin'), upload.single('image'), adminController.postCreateVehicle);
router.get('/vehicles/:id', requireAuth, vehicleController.getVehicleDetail);
router.post('/vehicles/:id/retire', requireRole('admin'), adminController.postRetireVehicle);

// 4. Trips
router.get('/trips', requireRole('dispatcher', 'admin'), tripController.listTrips);
router.get('/trips/create', requireRole('dispatcher', 'admin'), tripController.getCreateTrip);
router.post('/trips/create', requireRole('dispatcher', 'admin'), tripController.postCreateTrip);
router.post('/trips/:id/cancel', requireRole('dispatcher', 'admin'), tripController.postCancelTrip);
router.get('/trips/driver', requireRole('driver'), tripController.getDriverTrips);
router.post('/trips/:id/start', requireAuth, tripController.postStartTrip);
router.post('/trips/:id/end', requireAuth, tripController.postEndTrip);
router.get('/trips/:id/print', requireAuth, tripController.printDispatchOrder);

// 5. Fuel
router.get('/fuel', requireAuth, fuelController.listFuel);
router.get('/fuel/create', requireAuth, fuelController.getCreateFuel);
router.post('/fuel/create', requireAuth, fuelController.postCreateFuel);

// 6. Maintenance
router.get('/maintenance', requireRole('dispatcher', 'admin'), maintenanceController.listMaintenance);
router.get('/maintenance/create', requireRole('dispatcher', 'admin'), maintenanceController.getCreateMaintenance);
router.post('/maintenance/create', requireRole('dispatcher', 'admin'), maintenanceController.postCreateMaintenance);

// 7. Alerts
router.get('/alerts', requireRole('dispatcher', 'admin'), alertController.getAlerts);

// 8. KPI Dashboard
router.get('/kpi', requireRole('dispatcher', 'admin'), kpiController.getKPI);

// 9. Admin Management
router.get('/admin/vehicle-types', requireRole('admin'), adminController.listTypes);
router.post('/admin/vehicle-types', requireRole('admin'), adminController.postCreateType);
router.get('/admin/users', requireRole('admin'), adminController.listUsers);
router.get('/admin/users/create', requireRole('admin'), adminController.getCreateUser);
router.post('/admin/users/create', requireRole('admin'), adminController.postCreateUser);
router.post('/admin/users/:id/toggle', requireRole('admin'), adminController.postToggleUserStatus);

module.exports = router;

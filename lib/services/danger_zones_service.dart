import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DangerZonesService {
  static const List<DangerZone> dangerZones = [
    DangerZone(
      name: 'Johannesburg Central',
      points: [
        LatLng(-26.195, 28.040),
        LatLng(-26.205, 28.070),
        LatLng(-26.220, 28.060),
        LatLng(-26.215, 28.030),
        LatLng(-26.195, 28.040),
      ],
    ),
    DangerZone(
      name: 'Tembisa',
      points: [
        LatLng(-26.010, 28.220),
        LatLng(-26.000, 28.250),
        LatLng(-26.030, 28.260),
        LatLng(-26.040, 28.230),
        LatLng(-26.010, 28.220),
      ],
    ),
    DangerZone(
      name: 'Midrand',
      points: [
        LatLng(-25.990, 28.120),
        LatLng(-25.970, 28.150),
        LatLng(-26.000, 28.170),
        LatLng(-26.020, 28.140),
        LatLng(-25.990, 28.120),
      ],
    ),
    DangerZone(
      name: 'Roodepoort',
      points: [
        LatLng(-26.160, 27.870),
        LatLng(-26.140, 27.900),
        LatLng(-26.170, 27.930),
        LatLng(-26.190, 27.890),
        LatLng(-26.160, 27.870),
      ],
    ),
    DangerZone(
      name: 'Honeydew',
      points: [
        LatLng(-26.080, 27.920),
        LatLng(-26.060, 27.950),
        LatLng(-26.090, 27.970),
        LatLng(-26.100, 27.940),
        LatLng(-26.080, 27.920),
      ],
    ),
    DangerZone(
      name: 'Ivory Park',
      points: [
        LatLng(-26.030, 28.190),
        LatLng(-26.020, 28.220),
        LatLng(-26.050, 28.230),
        LatLng(-26.060, 28.200),
        LatLng(-26.030, 28.190),
      ],
    ),
    DangerZone(
      name: 'Kempton Park',
      points: [
        LatLng(-26.100, 28.230),
        LatLng(-26.080, 28.260),
        LatLng(-26.110, 28.280),
        LatLng(-26.130, 28.250),
        LatLng(-26.100, 28.230),
      ],
    ),
    DangerZone(
      name: 'Sandton',
      points: [
        LatLng(-26.110, 28.050),
        LatLng(-26.090, 28.080),
        LatLng(-26.120, 28.100),
        LatLng(-26.140, 28.060),
        LatLng(-26.110, 28.050),
      ],
    ),
    DangerZone(
      name: 'Sunnyside',
      points: [
        LatLng(-25.760, 28.220),
        LatLng(-25.740, 28.250),
        LatLng(-25.770, 28.260),
        LatLng(-25.790, 28.230),
        LatLng(-25.760, 28.220),
      ],
    ),
    DangerZone(
      name: 'Temba',
      points: [
        LatLng(-25.500, 28.200),
        LatLng(-25.480, 28.230),
        LatLng(-25.510, 28.250),
        LatLng(-25.520, 28.220),
        LatLng(-25.500, 28.200),
      ],
    ),
    DangerZone(
      name: 'Brooklyn',
      points: [
        LatLng(-25.770, 28.230),
        LatLng(-25.750, 28.260),
        LatLng(-25.780, 28.270),
        LatLng(-25.800, 28.240),
        LatLng(-25.770, 28.230),
      ],
    ),
    DangerZone(
      name: 'Mamelodi East',
      points: [
        LatLng(-25.700, 28.400),
        LatLng(-25.680, 28.430),
        LatLng(-25.710, 28.450),
        LatLng(-25.730, 28.420),
        LatLng(-25.700, 28.400),
      ],
    ),
    DangerZone(
      name: 'Hillbrow',
      points: [
        LatLng(-26.190, 28.040),
        LatLng(-26.180, 28.060),
        LatLng(-26.200, 28.070),
        LatLng(-26.210, 28.050),
        LatLng(-26.190, 28.040),
      ],
    ),
    DangerZone(
      name: 'Akasia',
      points: [
        LatLng(-25.650, 28.100),
        LatLng(-25.630, 28.130),
        LatLng(-25.660, 28.150),
        LatLng(-25.680, 28.120),
        LatLng(-25.650, 28.100),
      ],
    ),
    DangerZone(
      name: 'Eldorado Park',
      points: [
        LatLng(-26.290, 27.890),
        LatLng(-26.270, 27.920),
        LatLng(-26.300, 27.940),
        LatLng(-26.320, 27.910),
        LatLng(-26.290, 27.890),
      ],
    ),
    DangerZone(
      name: 'Alexandra',
      points: [
        LatLng(-26.110, 28.090),
        LatLng(-26.090, 28.120),
        LatLng(-26.120, 28.140),
        LatLng(-26.140, 28.100),
        LatLng(-26.110, 28.090),
      ],
    ),
    DangerZone(
      name: 'Krugersdorp',
      points: [
        LatLng(-26.100, 27.770),
        LatLng(-26.080, 27.800),
        LatLng(-26.110, 27.820),
        LatLng(-26.130, 27.790),
        LatLng(-26.100, 27.770),
      ],
    ),
    DangerZone(
      name: 'Jeppe',
      points: [
        LatLng(-26.210, 28.060),
        LatLng(-26.200, 28.090),
        LatLng(-26.230, 28.100),
        LatLng(-26.240, 28.070),
        LatLng(-26.210, 28.060),
      ],
    ),
    DangerZone(
      name: 'Germiston',
      points: [
        LatLng(-26.210, 28.170),
        LatLng(-26.190, 28.200),
        LatLng(-26.220, 28.220),
        LatLng(-26.240, 28.190),
        LatLng(-26.210, 28.170),
      ],
    ),
    DangerZone(
      name: 'Benoni',
      points: [
        LatLng(-26.150, 28.310),
        LatLng(-26.130, 28.340),
        LatLng(-26.160, 28.360),
        LatLng(-26.180, 28.330),
        LatLng(-26.150, 28.310),
      ],
    ),
    DangerZone(
      name: 'Durban Central',
      points: [
        LatLng(-29.860, 31.020),
        LatLng(-29.850, 31.050),
        LatLng(-29.880, 31.060),
        LatLng(-29.890, 31.030),
        LatLng(-29.860, 31.020),
      ],
    ),
    DangerZone(
      name: 'Phoenix',
      points: [
        LatLng(-29.710, 31.000),
        LatLng(-29.690, 31.030),
        LatLng(-29.720, 31.050),
        LatLng(-29.740, 31.020),
        LatLng(-29.710, 31.000),
      ],
    ),
    DangerZone(
      name: 'Chatsworth',
      points: [
        LatLng(-29.900, 30.860),
        LatLng(-29.880, 30.890),
        LatLng(-29.910, 30.910),
        LatLng(-29.930, 30.880),
        LatLng(-29.900, 30.860),
      ],
    ),
    DangerZone(
      name: 'Plessislaer',
      points: [
        LatLng(-29.630, 30.380),
        LatLng(-29.610, 30.410),
        LatLng(-29.640, 30.430),
        LatLng(-29.660, 30.400),
        LatLng(-29.630, 30.380),
      ],
    ),
    DangerZone(
      name: 'Inanda',
      points: [
        LatLng(-29.680, 31.020),
        LatLng(-29.660, 31.050),
        LatLng(-29.690, 31.070),
        LatLng(-29.710, 31.040),
        LatLng(-29.680, 31.020),
      ],
    ),
    DangerZone(
      name: 'Empangeni',
      points: [
        LatLng(-28.750, 31.900),
        LatLng(-28.730, 31.930),
        LatLng(-28.760, 31.950),
        LatLng(-28.780, 31.920),
        LatLng(-28.750, 31.900),
      ],
    ),
    DangerZone(
      name: 'Pinetown',
      points: [
        LatLng(-29.820, 30.850),
        LatLng(-29.800, 30.880),
        LatLng(-29.830, 30.900),
        LatLng(-29.850, 30.870),
        LatLng(-29.820, 30.850),
      ],
    ),
    DangerZone(
      name: 'KwaDukuza',
      points: [
        LatLng(-29.340, 31.280),
        LatLng(-29.320, 31.310),
        LatLng(-29.350, 31.330),
        LatLng(-29.370, 31.300),
        LatLng(-29.340, 31.280),
      ],
    ),
    DangerZone(
      name: 'Ladysmith',
      points: [
        LatLng(-28.560, 29.780),
        LatLng(-28.540, 29.810),
        LatLng(-28.570, 29.830),
        LatLng(-28.590, 29.800),
        LatLng(-28.560, 29.780),
      ],
    ),
    DangerZone(
      name: 'Verulam',
      points: [
        LatLng(-29.640, 31.050),
        LatLng(-29.620, 31.080),
        LatLng(-29.650, 31.100),
        LatLng(-29.670, 31.070),
        LatLng(-29.640, 31.050),
      ],
    ),
    DangerZone(
      name: 'Umlazi',
      points: [
        LatLng(-29.960, 30.900),
        LatLng(-29.940, 30.930),
        LatLng(-29.970, 30.950),
        LatLng(-29.990, 30.920),
        LatLng(-29.960, 30.900),
      ],
    ),
    DangerZone(
      name: 'Mountain Rise',
      points: [
        LatLng(-29.610, 30.360),
        LatLng(-29.590, 30.390),
        LatLng(-29.620, 30.410),
        LatLng(-29.640, 30.380),
        LatLng(-29.610, 30.360),
      ],
    ),
    DangerZone(
      name: 'Pietermaritzburg',
      points: [
        LatLng(-29.590, 30.410),
        LatLng(-29.570, 30.440),
        LatLng(-29.600, 30.460),
        LatLng(-29.620, 30.430),
        LatLng(-29.590, 30.410),
      ],
    ),
    DangerZone(
      name: 'Newcastle',
      points: [
        LatLng(-27.760, 29.930),
        LatLng(-27.740, 29.960),
        LatLng(-27.770, 29.980),
        LatLng(-27.790, 29.950),
        LatLng(-27.760, 29.930),
      ],
    ),
    DangerZone(
      name: 'Madadeni',
      points: [
        LatLng(-27.730, 29.900),
        LatLng(-27.710, 29.930),
        LatLng(-27.740, 29.950),
        LatLng(-27.760, 29.920),
        LatLng(-27.730, 29.900),
      ],
    ),
    DangerZone(
      name: 'Osizweni',
      points: [
        LatLng(-27.790, 29.880),
        LatLng(-27.770, 29.910),
        LatLng(-27.800, 29.930),
        LatLng(-27.820, 29.900),
        LatLng(-27.790, 29.880),
      ],
    ),
    DangerZone(
      name: 'Margate',
      points: [
        LatLng(-30.850, 30.370),
        LatLng(-30.830, 30.400),
        LatLng(-30.860, 30.420),
        LatLng(-30.880, 30.390),
        LatLng(-30.850, 30.370),
      ],
    ),
    DangerZone(
      name: 'Richards Bay',
      points: [
        LatLng(-28.780, 32.060),
        LatLng(-28.760, 32.090),
        LatLng(-28.790, 32.110),
        LatLng(-28.810, 32.080),
        LatLng(-28.780, 32.060),
      ],
    ),
    DangerZone(
      name: 'Port Shepstone',
      points: [
        LatLng(-30.740, 30.450),
        LatLng(-30.720, 30.480),
        LatLng(-30.750, 30.500),
        LatLng(-30.770, 30.470),
        LatLng(-30.740, 30.450),
      ],
    ),
    DangerZone(
      name: 'Ntuzuma',
      points: [
        LatLng(-29.730, 30.980),
        LatLng(-29.710, 31.010),
        LatLng(-29.740, 31.030),
        LatLng(-29.760, 31.000),
        LatLng(-29.730, 30.980),
      ],
    ),
    DangerZone(
      name: 'Polokwane',
      points: [
        LatLng(-23.900, 29.450),
        LatLng(-23.880, 29.480),
        LatLng(-23.910, 29.500),
        LatLng(-23.930, 29.470),
        LatLng(-23.900, 29.450),
      ],
    ),
    DangerZone(
      name: 'Mankweng',
      points: [
        LatLng(-23.860, 29.690),
        LatLng(-23.840, 29.720),
        LatLng(-23.870, 29.740),
        LatLng(-23.890, 29.710),
        LatLng(-23.860, 29.690),
      ],
    ),
    DangerZone(
      name: 'Thohoyandou',
      points: [
        LatLng(-22.950, 30.480),
        LatLng(-22.930, 30.510),
        LatLng(-22.960, 30.530),
        LatLng(-22.980, 30.500),
        LatLng(-22.950, 30.480),
      ],
    ),
    DangerZone(
      name: 'Seshego',
      points: [
        LatLng(-23.850, 29.380),
        LatLng(-23.830, 29.410),
        LatLng(-23.860, 29.430),
        LatLng(-23.880, 29.400),
        LatLng(-23.850, 29.380),
      ],
    ),
    DangerZone(
      name: 'Lebowakgomo',
      points: [
        LatLng(-24.200, 29.500),
        LatLng(-24.180, 29.530),
        LatLng(-24.210, 29.550),
        LatLng(-24.230, 29.520),
        LatLng(-24.200, 29.500),
      ],
    ),
    DangerZone(
      name: 'Giyani',
      points: [
        LatLng(-23.300, 30.700),
        LatLng(-23.280, 30.730),
        LatLng(-23.310, 30.750),
        LatLng(-23.330, 30.720),
        LatLng(-23.300, 30.700),
      ],
    ),
    DangerZone(
      name: 'Mahwelereng',
      points: [
        LatLng(-24.180, 28.980),
        LatLng(-24.160, 29.010),
        LatLng(-24.190, 29.030),
        LatLng(-24.210, 29.000),
        LatLng(-24.180, 28.980),
      ],
    ),
    DangerZone(
      name: 'Maake',
      points: [
        LatLng(-23.680, 30.660),
        LatLng(-23.660, 30.690),
        LatLng(-23.690, 30.710),
        LatLng(-23.710, 30.680),
        LatLng(-23.680, 30.660),
      ],
    ),
    DangerZone(
      name: 'Tzaneen',
      points: [
        LatLng(-23.830, 30.160),
        LatLng(-23.810, 30.190),
        LatLng(-23.840, 30.210),
        LatLng(-23.860, 30.180),
        LatLng(-23.830, 30.160),
      ],
    ),
    DangerZone(
      name: 'Westenburg',
      points: [
        LatLng(-23.920, 29.430),
        LatLng(-23.900, 29.460),
        LatLng(-23.930, 29.480),
        LatLng(-23.950, 29.450),
        LatLng(-23.920, 29.430),
      ],
    ),
    DangerZone(
      name: 'Dennilton',
      points: [
        LatLng(-25.290, 29.050),
        LatLng(-25.270, 29.080),
        LatLng(-25.300, 29.100),
        LatLng(-25.320, 29.070),
        LatLng(-25.290, 29.050),
      ],
    ),
    DangerZone(
      name: 'Bela-Bela',
      points: [
        LatLng(-24.890, 28.290),
        LatLng(-24.870, 28.320),
        LatLng(-24.900, 28.340),
        LatLng(-24.920, 28.310),
        LatLng(-24.890, 28.290),
      ],
    ),
    DangerZone(
      name: 'Mokopane',
      points: [
        LatLng(-24.180, 29.010),
        LatLng(-24.160, 29.040),
        LatLng(-24.190, 29.060),
        LatLng(-24.210, 29.030),
        LatLng(-24.180, 29.010),
      ],
    ),
    DangerZone(
      name: 'Bolobedu',
      points: [
        LatLng(-23.620, 30.420),
        LatLng(-23.600, 30.450),
        LatLng(-23.630, 30.470),
        LatLng(-23.650, 30.440),
        LatLng(-23.620, 30.420),
      ],
    ),
    DangerZone(
      name: 'Burgersfort',
      points: [
        LatLng(-24.700, 30.350),
        LatLng(-24.680, 30.380),
        LatLng(-24.710, 30.400),
        LatLng(-24.730, 30.370),
        LatLng(-24.700, 30.350),
      ],
    ),
    DangerZone(
      name: 'Namakgale',
      points: [
        LatLng(-23.930, 30.920),
        LatLng(-23.910, 30.950),
        LatLng(-23.940, 30.970),
        LatLng(-23.960, 30.940),
        LatLng(-23.930, 30.920),
      ],
    ),
    DangerZone(
      name: 'Musina',
      points: [
        LatLng(-22.350, 30.040),
        LatLng(-22.330, 30.070),
        LatLng(-22.360, 30.090),
        LatLng(-22.380, 30.060),
        LatLng(-22.350, 30.040),
      ],
    ),
    DangerZone(
      name: 'Lephalale',
      points: [
        LatLng(-23.680, 27.750),
        LatLng(-23.660, 27.780),
        LatLng(-23.690, 27.800),
        LatLng(-23.710, 27.770),
        LatLng(-23.680, 27.750),
      ],
    ),
    DangerZone(
      name: 'Modimolle',
      points: [
        LatLng(-24.700, 28.400),
        LatLng(-24.680, 28.430),
        LatLng(-24.710, 28.450),
        LatLng(-24.730, 28.420),
        LatLng(-24.700, 28.400),
      ],
    ),
    DangerZone(
      name: 'Ritavi',
      points: [
        LatLng(-23.750, 30.380),
        LatLng(-23.730, 30.410),
        LatLng(-23.760, 30.430),
        LatLng(-23.780, 30.400),
        LatLng(-23.750, 30.380),
      ],
    ),
    DangerZone(
      name: 'Witbank',
      points: [
        LatLng(-25.870, 29.230),
        LatLng(-25.850, 29.260),
        LatLng(-25.880, 29.280),
        LatLng(-25.900, 29.250),
        LatLng(-25.870, 29.230),
      ],
    ),
    DangerZone(
      name: 'Nelspruit',
      points: [
        LatLng(-25.460, 30.970),
        LatLng(-25.440, 31.000),
        LatLng(-25.470, 31.020),
        LatLng(-25.490, 30.990),
        LatLng(-25.460, 30.970),
      ],
    ),
    DangerZone(
      name: 'Middelburg',
      points: [
        LatLng(-25.770, 29.450),
        LatLng(-25.750, 29.480),
        LatLng(-25.780, 29.500),
        LatLng(-25.800, 29.470),
        LatLng(-25.770, 29.450),
      ],
    ),
    DangerZone(
      name: 'Vosman',
      points: [
        LatLng(-25.890, 29.200),
        LatLng(-25.870, 29.230),
        LatLng(-25.900, 29.250),
        LatLng(-25.920, 29.220),
        LatLng(-25.890, 29.200),
      ],
    ),
    DangerZone(
      name: 'KwaMhlanga',
      points: [
        LatLng(-25.440, 28.780),
        LatLng(-25.420, 28.810),
        LatLng(-25.450, 28.830),
        LatLng(-25.470, 28.800),
        LatLng(-25.440, 28.780),
      ],
    ),
    DangerZone(
      name: 'Ermelo',
      points: [
        LatLng(-26.530, 29.980),
        LatLng(-26.510, 30.010),
        LatLng(-26.540, 30.030),
        LatLng(-26.560, 30.000),
        LatLng(-26.530, 29.980),
      ],
    ),
    DangerZone(
      name: 'Delmas',
      points: [
        LatLng(-26.150, 28.680),
        LatLng(-26.130, 28.710),
        LatLng(-26.160, 28.730),
        LatLng(-26.180, 28.700),
        LatLng(-26.150, 28.680),
      ],
    ),
    DangerZone(
      name: 'Standerton',
      points: [
        LatLng(-26.930, 29.220),
        LatLng(-26.910, 29.250),
        LatLng(-26.940, 29.270),
        LatLng(-26.960, 29.240),
        LatLng(-26.930, 29.220),
      ],
    ),
    DangerZone(
      name: 'Barberton',
      points: [
        LatLng(-25.780, 31.050),
        LatLng(-25.760, 31.080),
        LatLng(-25.790, 31.100),
        LatLng(-25.810, 31.070),
        LatLng(-25.780, 31.050),
      ],
    ),
    DangerZone(
      name: 'Embalenhle',
      points: [
        LatLng(-26.530, 29.080),
        LatLng(-26.510, 29.110),
        LatLng(-26.540, 29.130),
        LatLng(-26.560, 29.100),
        LatLng(-26.530, 29.080),
      ],
    ),
    DangerZone(
      name: 'Kabokweni',
      points: [
        LatLng(-25.390, 31.110),
        LatLng(-25.370, 31.140),
        LatLng(-25.400, 31.160),
        LatLng(-25.420, 31.130),
        LatLng(-25.390, 31.110),
      ],
    ),
    DangerZone(
      name: 'Pienaar',
      points: [
        LatLng(-25.350, 31.040),
        LatLng(-25.330, 31.070),
        LatLng(-25.360, 31.090),
        LatLng(-25.380, 31.060),
        LatLng(-25.350, 31.040),
      ],
    ),
    DangerZone(
      name: 'Siyabuswa',
      points: [
        LatLng(-25.120, 29.050),
        LatLng(-25.100, 29.080),
        LatLng(-25.130, 29.100),
        LatLng(-25.150, 29.070),
        LatLng(-25.120, 29.050),
      ],
    ),
    DangerZone(
      name: 'Secunda',
      points: [
        LatLng(-26.500, 29.180),
        LatLng(-26.480, 29.210),
        LatLng(-26.510, 29.230),
        LatLng(-26.530, 29.200),
        LatLng(-26.500, 29.180),
      ],
    ),
    DangerZone(
      name: 'Piet Retief',
      points: [
        LatLng(-27.000, 30.800),
        LatLng(-26.980, 30.830),
        LatLng(-27.010, 30.850),
        LatLng(-27.030, 30.820),
        LatLng(-27.000, 30.800),
      ],
    ),
    DangerZone(
      name: 'Bushbuckridge',
      points: [
        LatLng(-24.830, 31.050),
        LatLng(-24.810, 31.080),
        LatLng(-24.840, 31.100),
        LatLng(-24.860, 31.070),
        LatLng(-24.830, 31.050),
      ],
    ),
    DangerZone(
      name: 'Masoyi',
      points: [
        LatLng(-25.280, 31.080),
        LatLng(-25.260, 31.110),
        LatLng(-25.290, 31.130),
        LatLng(-25.310, 31.100),
        LatLng(-25.280, 31.080),
      ],
    ),
    DangerZone(
      name: 'Calcutta',
      points: [
        LatLng(-25.420, 31.210),
        LatLng(-25.400, 31.240),
        LatLng(-25.430, 31.260),
        LatLng(-25.450, 31.230),
        LatLng(-25.420, 31.210),
      ],
    ),
    DangerZone(
      name: 'White River',
      points: [
        LatLng(-25.320, 31.010),
        LatLng(-25.300, 31.040),
        LatLng(-25.330, 31.060),
        LatLng(-25.350, 31.030),
        LatLng(-25.320, 31.010),
      ],
    ),
    DangerZone(
      name: 'Acornhoek',
      points: [
        LatLng(-24.680, 31.120),
        LatLng(-24.660, 31.150),
        LatLng(-24.690, 31.170),
        LatLng(-24.710, 31.140),
        LatLng(-24.680, 31.120),
      ],
    ),
    DangerZone(
      name: 'Kimberley',
      points: [
        LatLng(-28.730, 24.760),
        LatLng(-28.710, 24.790),
        LatLng(-28.740, 24.810),
        LatLng(-28.760, 24.780),
        LatLng(-28.730, 24.760),
      ],
    ),
    DangerZone(
      name: 'Galeshewe',
      points: [
        LatLng(-28.750, 24.720),
        LatLng(-28.730, 24.750),
        LatLng(-28.760, 24.770),
        LatLng(-28.780, 24.740),
        LatLng(-28.750, 24.720),
      ],
    ),
    DangerZone(
      name: 'Upington',
      points: [
        LatLng(-28.450, 21.250),
        LatLng(-28.430, 21.280),
        LatLng(-28.460, 21.300),
        LatLng(-28.480, 21.270),
        LatLng(-28.450, 21.250),
      ],
    ),
    DangerZone(
      name: 'Roodepan',
      points: [
        LatLng(-28.700, 24.700),
        LatLng(-28.680, 24.730),
        LatLng(-28.710, 24.750),
        LatLng(-28.730, 24.720),
        LatLng(-28.700, 24.700),
      ],
    ),
    DangerZone(
      name: 'Postmasburg',
      points: [
        LatLng(-28.330, 23.070),
        LatLng(-28.310, 23.100),
        LatLng(-28.340, 23.120),
        LatLng(-28.360, 23.090),
        LatLng(-28.330, 23.070),
      ],
    ),
    DangerZone(
      name: 'Kagisho',
      points: [
        LatLng(-28.730, 24.780),
        LatLng(-28.710, 24.810),
        LatLng(-28.740, 24.830),
        LatLng(-28.760, 24.800),
        LatLng(-28.730, 24.780),
      ],
    ),
    DangerZone(
      name: 'Rosedale',
      points: [
        LatLng(-28.470, 21.210),
        LatLng(-28.450, 21.240),
        LatLng(-28.480, 21.260),
        LatLng(-28.500, 21.230),
        LatLng(-28.470, 21.210),
      ],
    ),
    DangerZone(
      name: 'Kuruman',
      points: [
        LatLng(-27.460, 23.430),
        LatLng(-27.440, 23.460),
        LatLng(-27.470, 23.480),
        LatLng(-27.490, 23.450),
        LatLng(-27.460, 23.430),
      ],
    ),
    DangerZone(
      name: 'Mothibistad',
      points: [
        LatLng(-27.400, 23.420),
        LatLng(-27.380, 23.450),
        LatLng(-27.410, 23.470),
        LatLng(-27.430, 23.440),
        LatLng(-27.400, 23.420),
      ],
    ),
    DangerZone(
      name: 'Kakamas',
      points: [
        LatLng(-28.780, 20.620),
        LatLng(-28.760, 20.650),
        LatLng(-28.790, 20.670),
        LatLng(-28.810, 20.640),
        LatLng(-28.780, 20.620),
      ],
    ),
    DangerZone(
      name: 'Jan Kempdorp',
      points: [
        LatLng(-27.920, 24.830),
        LatLng(-27.900, 24.860),
        LatLng(-27.930, 24.880),
        LatLng(-27.950, 24.850),
        LatLng(-27.920, 24.830),
      ],
    ),
    DangerZone(
      name: 'Douglas',
      points: [
        LatLng(-29.050, 23.770),
        LatLng(-29.030, 23.800),
        LatLng(-29.060, 23.820),
        LatLng(-29.080, 23.790),
        LatLng(-29.050, 23.770),
      ],
    ),
    DangerZone(
      name: 'Kathu',
      points: [
        LatLng(-27.690, 23.050),
        LatLng(-27.670, 23.080),
        LatLng(-27.700, 23.100),
        LatLng(-27.720, 23.070),
        LatLng(-27.690, 23.050),
      ],
    ),
    DangerZone(
      name: 'Warrenton',
      points: [
        LatLng(-28.110, 24.850),
        LatLng(-28.090, 24.880),
        LatLng(-28.120, 24.900),
        LatLng(-28.140, 24.870),
        LatLng(-28.110, 24.850),
      ],
    ),
    DangerZone(
      name: 'Modder River',
      points: [
        LatLng(-29.030, 24.630),
        LatLng(-29.010, 24.660),
        LatLng(-29.040, 24.680),
        LatLng(-29.060, 24.650),
        LatLng(-29.030, 24.630),
      ],
    ),
    DangerZone(
      name: 'Springbok',
      points: [
        LatLng(-29.670, 17.880),
        LatLng(-29.650, 17.910),
        LatLng(-29.680, 17.930),
        LatLng(-29.700, 17.900),
        LatLng(-29.670, 17.880),
      ],
    ),
    DangerZone(
      name: 'Hartswater',
      points: [
        LatLng(-27.750, 24.800),
        LatLng(-27.730, 24.830),
        LatLng(-27.760, 24.850),
        LatLng(-27.780, 24.820),
        LatLng(-27.750, 24.800),
      ],
    ),
    DangerZone(
      name: 'Barkly West',
      points: [
        LatLng(-28.530, 24.530),
        LatLng(-28.510, 24.560),
        LatLng(-28.540, 24.580),
        LatLng(-28.560, 24.550),
        LatLng(-28.530, 24.530),
      ],
    ),
    DangerZone(
      name: 'Pabalello',
      points: [
        LatLng(-28.780, 24.650),
        LatLng(-28.760, 24.680),
        LatLng(-28.790, 24.700),
        LatLng(-28.810, 24.670),
        LatLng(-28.780, 24.650),
      ],
    ),
    DangerZone(
      name: 'De Aar',
      points: [
        LatLng(-30.650, 24.010),
        LatLng(-30.630, 24.040),
        LatLng(-30.660, 24.060),
        LatLng(-30.680, 24.030),
        LatLng(-30.650, 24.010),
      ],
    ),
    DangerZone(
      name: 'Rustenburg',
      points: [
        LatLng(-25.650, 27.240),
        LatLng(-25.630, 27.270),
        LatLng(-25.660, 27.290),
        LatLng(-25.680, 27.260),
        LatLng(-25.650, 27.240),
      ],
    ),
    DangerZone(
      name: 'Brits',
      points: [
        LatLng(-25.630, 27.780),
        LatLng(-25.610, 27.810),
        LatLng(-25.640, 27.830),
        LatLng(-25.660, 27.800),
        LatLng(-25.630, 27.780),
      ],
    ),
    DangerZone(
      name: 'Klerksdorp',
      points: [
        LatLng(-26.860, 26.660),
        LatLng(-26.840, 26.690),
        LatLng(-26.870, 26.710),
        LatLng(-26.890, 26.680),
        LatLng(-26.860, 26.660),
      ],
    ),
    DangerZone(
      name: 'Lethabile',
      points: [
        LatLng(-25.870, 25.580),
        LatLng(-25.850, 25.610),
        LatLng(-25.880, 25.630),
        LatLng(-25.900, 25.600),
        LatLng(-25.870, 25.580),
      ],
    ),
    DangerZone(
      name: 'Mmabatho',
      points: [
        LatLng(-25.850, 25.620),
        LatLng(-25.830, 25.650),
        LatLng(-25.860, 25.670),
        LatLng(-25.880, 25.640),
        LatLng(-25.850, 25.620),
      ],
    ),
    DangerZone(
      name: 'Ikageng',
      points: [
        LatLng(-26.700, 27.080),
        LatLng(-26.680, 27.110),
        LatLng(-26.710, 27.130),
        LatLng(-26.730, 27.100),
        LatLng(-26.700, 27.080),
      ],
    ),
    DangerZone(
      name: 'Mahikeng',
      points: [
        LatLng(-25.860, 25.630),
        LatLng(-25.840, 25.660),
        LatLng(-25.870, 25.680),
        LatLng(-25.890, 25.650),
        LatLng(-25.860, 25.630),
      ],
    ),
    DangerZone(
      name: 'Tlhobane',
      points: [
        LatLng(-25.910, 25.610),
        LatLng(-25.890, 25.640),
        LatLng(-25.920, 25.660),
        LatLng(-25.940, 25.630),
        LatLng(-25.910, 25.610),
      ],
    ),
    DangerZone(
      name: 'Boitekong',
      points: [
        LatLng(-25.610, 27.220),
        LatLng(-25.590, 27.250),
        LatLng(-25.620, 27.270),
        LatLng(-25.640, 27.240),
        LatLng(-25.610, 27.220),
      ],
    ),
    DangerZone(
      name: 'Mogwase',
      points: [
        LatLng(-25.310, 27.120),
        LatLng(-25.290, 27.150),
        LatLng(-25.320, 27.170),
        LatLng(-25.340, 27.140),
        LatLng(-25.310, 27.120),
      ],
    ),
    DangerZone(
      name: 'Potchefstroom',
      points: [
        LatLng(-26.710, 27.090),
        LatLng(-26.690, 27.120),
        LatLng(-26.720, 27.140),
        LatLng(-26.740, 27.110),
        LatLng(-26.710, 27.090),
      ],
    ),
    DangerZone(
      name: 'Mooinooi',
      points: [
        LatLng(-25.650, 27.550),
        LatLng(-25.630, 27.580),
        LatLng(-25.660, 27.600),
        LatLng(-25.680, 27.570),
        LatLng(-25.650, 27.550),
      ],
    ),
    DangerZone(
      name: 'Jouberton',
      points: [
        LatLng(-26.840, 26.610),
        LatLng(-26.820, 26.640),
        LatLng(-26.850, 26.660),
        LatLng(-26.870, 26.630),
        LatLng(-26.840, 26.610),
      ],
    ),
    DangerZone(
      name: 'Phokeng',
      points: [
        LatLng(-25.570, 27.120),
        LatLng(-25.550, 27.150),
        LatLng(-25.580, 27.170),
        LatLng(-25.600, 27.140),
        LatLng(-25.570, 27.120),
      ],
    ),
    DangerZone(
      name: 'Hartbeespoortdam',
      points: [
        LatLng(-25.750, 27.850),
        LatLng(-25.730, 27.880),
        LatLng(-25.760, 27.900),
        LatLng(-25.780, 27.870),
        LatLng(-25.750, 27.850),
      ],
    ),
    DangerZone(
      name: 'Lichtenburg',
      points: [
        LatLng(-26.150, 26.160),
        LatLng(-26.130, 26.190),
        LatLng(-26.160, 26.210),
        LatLng(-26.180, 26.180),
        LatLng(-26.150, 26.160),
      ],
    ),
    DangerZone(
      name: 'Makapanstad',
      points: [
        LatLng(-25.230, 28.120),
        LatLng(-25.210, 28.150),
        LatLng(-25.240, 28.170),
        LatLng(-25.260, 28.140),
        LatLng(-25.230, 28.120),
      ],
    ),
    DangerZone(
      name: 'Ventersdorp',
      points: [
        LatLng(-26.310, 26.820),
        LatLng(-26.290, 26.850),
        LatLng(-26.320, 26.870),
        LatLng(-26.340, 26.840),
        LatLng(-26.310, 26.820),
      ],
    ),
    DangerZone(
      name: 'Taung',
      points: [
        LatLng(-27.540, 24.730),
        LatLng(-27.520, 24.760),
        LatLng(-27.550, 24.780),
        LatLng(-27.570, 24.750),
        LatLng(-27.540, 24.730),
      ],
    ),
    DangerZone(
      name: 'Klipgat',
      points: [
        LatLng(-25.430, 27.980),
        LatLng(-25.410, 28.010),
        LatLng(-25.440, 28.030),
        LatLng(-25.460, 28.000),
        LatLng(-25.430, 27.980),
      ],
    ),
    DangerZone(
      name: 'Cape Town Central',
      points: [
        LatLng(-33.920, 18.420),
        LatLng(-33.910, 18.450),
        LatLng(-33.940, 18.460),
        LatLng(-33.950, 18.430),
        LatLng(-33.920, 18.420),
      ],
    ),
    DangerZone(
      name: 'Mitchells Plain',
      points: [
        LatLng(-34.050, 18.620),
        LatLng(-34.030, 18.650),
        LatLng(-34.060, 18.670),
        LatLng(-34.080, 18.640),
        LatLng(-34.050, 18.620),
      ],
    ),
    DangerZone(
      name: 'Delft',
      points: [
        LatLng(-33.980, 18.620),
        LatLng(-33.960, 18.650),
        LatLng(-33.990, 18.670),
        LatLng(-34.010, 18.640),
        LatLng(-33.980, 18.620),
      ],
    ),
    DangerZone(
      name: 'Mfuleni',
      points: [
        LatLng(-34.010, 18.670),
        LatLng(-33.990, 18.700),
        LatLng(-34.020, 18.720),
        LatLng(-34.040, 18.690),
        LatLng(-34.010, 18.670),
      ],
    ),
    DangerZone(
      name: 'Kraaifontein',
      points: [
        LatLng(-33.850, 18.720),
        LatLng(-33.830, 18.750),
        LatLng(-33.860, 18.770),
        LatLng(-33.880, 18.740),
        LatLng(-33.850, 18.720),
      ],
    ),
    DangerZone(
      name: 'Worcester',
      points: [
        LatLng(-33.640, 19.440),
        LatLng(-33.620, 19.470),
        LatLng(-33.650, 19.490),
        LatLng(-33.670, 19.460),
        LatLng(-33.640, 19.440),
      ],
    ),
    DangerZone(
      name: 'Nyanga',
      points: [
        LatLng(-33.980, 18.580),
        LatLng(-33.960, 18.610),
        LatLng(-33.990, 18.630),
        LatLng(-34.010, 18.600),
        LatLng(-33.980, 18.580),
      ],
    ),
    DangerZone(
      name: 'Kleinvlei',
      points: [
        LatLng(-34.010, 18.630),
        LatLng(-33.990, 18.660),
        LatLng(-34.020, 18.680),
        LatLng(-34.040, 18.650),
        LatLng(-34.010, 18.630),
      ],
    ),
    DangerZone(
      name: 'Atlantis',
      points: [
        LatLng(-33.570, 18.480),
        LatLng(-33.550, 18.510),
        LatLng(-33.580, 18.530),
        LatLng(-33.600, 18.500),
        LatLng(-33.570, 18.480),
      ],
    ),
    DangerZone(
      name: 'Stellenbosch',
      points: [
        LatLng(-33.930, 18.860),
        LatLng(-33.910, 18.890),
        LatLng(-33.940, 18.910),
        LatLng(-33.960, 18.880),
        LatLng(-33.930, 18.860),
      ],
    ),
    DangerZone(
      name: 'Bishop Lavis',
      points: [
        LatLng(-33.950, 18.580),
        LatLng(-33.930, 18.610),
        LatLng(-33.960, 18.630),
        LatLng(-33.980, 18.600),
        LatLng(-33.950, 18.580),
      ],
    ),
    DangerZone(
      name: 'Lentegeur',
      points: [
        LatLng(-34.020, 18.640),
        LatLng(-34.000, 18.670),
        LatLng(-34.030, 18.690),
        LatLng(-34.050, 18.660),
        LatLng(-34.020, 18.640),
      ],
    ),
    DangerZone(
      name: 'Khayelitsha',
      points: [
        LatLng(-34.040, 18.680),
        LatLng(-34.020, 18.710),
        LatLng(-34.050, 18.730),
        LatLng(-34.070, 18.700),
        LatLng(-34.040, 18.680),
      ],
    ),
    DangerZone(
      name: 'Knysna',
      points: [
        LatLng(-34.030, 23.040),
        LatLng(-34.010, 23.070),
        LatLng(-34.040, 23.090),
        LatLng(-34.060, 23.060),
        LatLng(-34.030, 23.040),
      ],
    ),
    DangerZone(
      name: 'Bellville',
      points: [
        LatLng(-33.900, 18.620),
        LatLng(-33.880, 18.650),
        LatLng(-33.910, 18.670),
        LatLng(-33.930, 18.640),
        LatLng(-33.900, 18.620),
      ],
    ),
    DangerZone(
      name: 'Grassy Park',
      points: [
        LatLng(-34.050, 18.510),
        LatLng(-34.030, 18.540),
        LatLng(-34.060, 18.560),
        LatLng(-34.080, 18.530),
        LatLng(-34.050, 18.510),
      ],
    ),
    DangerZone(
      name: 'Milnerton',
      points: [
        LatLng(-33.870, 18.490),
        LatLng(-33.850, 18.520),
        LatLng(-33.880, 18.540),
        LatLng(-33.900, 18.510),
        LatLng(-33.870, 18.490),
      ],
    ),
    DangerZone(
      name: 'Paarl East',
      points: [
        LatLng(-33.740, 19.020),
        LatLng(-33.720, 19.050),
        LatLng(-33.750, 19.070),
        LatLng(-33.770, 19.040),
        LatLng(-33.740, 19.020),
      ],
    ),
    DangerZone(
      name: 'Hermanus',
      points: [
        LatLng(-34.410, 19.240),
        LatLng(-34.390, 19.270),
        LatLng(-34.420, 19.290),
        LatLng(-34.440, 19.260),
        LatLng(-34.410, 19.240),
      ],
    ),
    DangerZone(
      name: 'Gugulethu',
      points: [
        LatLng(-33.970, 18.560),
        LatLng(-33.950, 18.590),
        LatLng(-33.980, 18.610),
        LatLng(-34.000, 18.580),
        LatLng(-33.970, 18.560),
      ],
    ),
    DangerZone(
      name: 'Maokeng',
      points: [
        LatLng(-27.990, 26.710),
        LatLng(-27.970, 26.740),
        LatLng(-28.000, 26.760),
        LatLng(-28.020, 26.730),
        LatLng(-27.990, 26.710),
      ],
    ),
    DangerZone(
      name: 'Heidedal',
      points: [
        LatLng(-29.080, 26.220),
        LatLng(-29.060, 26.250),
        LatLng(-29.090, 26.270),
        LatLng(-29.110, 26.240),
        LatLng(-29.080, 26.220),
      ],
    ),
    DangerZone(
      name: 'Kroonstad',
      points: [
        LatLng(-27.660, 27.230),
        LatLng(-27.640, 27.260),
        LatLng(-27.670, 27.280),
        LatLng(-27.690, 27.250),
        LatLng(-27.660, 27.230),
      ],
    ),
    DangerZone(
      name: 'Bethlehem',
      points: [
        LatLng(-28.230, 28.300),
        LatLng(-28.210, 28.330),
        LatLng(-28.240, 28.350),
        LatLng(-28.260, 28.320),
        LatLng(-28.230, 28.300),
      ],
    ),
    DangerZone(
      name: 'Bothaville',
      points: [
        LatLng(-27.380, 26.610),
        LatLng(-27.360, 26.640),
        LatLng(-27.390, 26.660),
        LatLng(-27.410, 26.630),
        LatLng(-27.380, 26.610),
      ],
    ),
    DangerZone(
      name: 'Selosesha',
      points: [
        LatLng(-29.130, 26.700),
        LatLng(-29.110, 26.730),
        LatLng(-29.140, 26.750),
        LatLng(-29.160, 26.720),
        LatLng(-29.130, 26.700),
      ],
    ),
    DangerZone(
      name: 'Sasolburg',
      points: [
        LatLng(-26.810, 27.810),
        LatLng(-26.790, 27.840),
        LatLng(-26.820, 27.860),
        LatLng(-26.840, 27.830),
        LatLng(-26.810, 27.810),
      ],
    ),
  ];
}

class DangerZone {
  final String name;
  final List<LatLng> points;

  const DangerZone({
    required this.name,
    required this.points,
  });

  Polygon toPolygon() {
    return Polygon(
      polygonId: PolygonId(name.replaceAll(' ', '_')),
      points: points,
      fillColor: Color(0x66FF0000),   // red with 40% opacity
      strokeColor: Color(0xFFFF0000), // solid red border
      strokeWidth: 2,
      geodesic: true,
    );
  
  }
}
-- ==============================================================================
-- Stage 10 Product Catalog Database Seed (16 Products)
-- ==============================================================================
INSERT INTO categories (id, name, description) VALUES
(1, 'Audio & Electronics', 'High fidelity audio equipment, noise-canceling gear, and accessories'),
(2, 'Wearables', 'Next-gen smart wearables, fitness trackers, and connected devices'),
(3, 'Smart Home', 'Connected smart lamps, voice hubs, and home automation systems'),
(4, 'Computer Peripherals', 'Productivity gear, mechanical keyboards, and precision peripherals'),
(5, 'Developer Gear', 'Neural compute devices, hardware security tokens, and dev tools'),
(6, 'Cloud & Networking', 'Managed high-speed enterprise switches and networking hardware')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO products (id, category_id, name, description, price, stock_quantity, image_url) VALUES
(1, 1, 'CloudBeats ANC Wireless Headphones', 'Active noise cancelling wireless headphones with 40-hour battery life and spatial audio.', 199.99, 45, 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&auto=format&fit=crop&q=60'),
(2, 2, 'ShopSphere Apex Smart Watch', 'AMOLED display, continuous ECG & SpO2 tracking, 7-day battery, and 5ATM water resistance.', 249.99, 30, 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&auto=format&fit=crop&q=60'),
(3, 1, 'UltraHD 4K Action Camera', 'Compact waterproof 4K/60fps camera with 6-axis gyro stabilization and dual screens.', 129.99, 25, 'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=500&auto=format&fit=crop&q=60'),
(4, 3, 'Aurora Smart RGB Desk Lamp', 'Voice-controlled ambient lighting with custom gradients, timer routines, and adaptive brightness.', 49.99, 60, 'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=500&auto=format&fit=crop&q=60'),
(5, 4, 'CyberDeck RGB Mechanical Keyboard', 'Hot-swappable tactile mechanical switches, PBT keycaps, and aircraft-grade aluminum chassis.', 89.99, 40, 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=500&auto=format&fit=crop&q=60'),
(6, 1, 'HyperCharge 20000mAh Power Bank', '65W USB-C Power Delivery fast-charging power bank for laptops, tablets, and smartphones.', 39.99, 75, 'https://images.unsplash.com/photo-1609592426507-da665123d537?w=500&auto=format&fit=crop&q=60'),
(7, 4, 'QuantumDrive 2TB NVMe Gen4 SSD', 'Ultra-fast 7,400 MB/s read speeds, PCIe 4.0 interface with integrated graphite thermal heatsink.', 179.99, 50, 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=500&auto=format&fit=crop&q=60'),
(8, 4, 'AeroShield 27-inch 4K HDR Monitor', 'IPS panel with 99% DCI-P3 color gamut, USB-C 90W single-cable docking, and ergonomic stand.', 389.99, 20, 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=500&auto=format&fit=crop&q=60'),
(9, 4, 'Nimbus Pro Ultra-Light Wireless Mouse', '58-gram honeycomb ultralight design, 26,000 DPI optical sensor, and low-latency 2.4GHz wireless.', 69.99, 90, 'https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=500&auto=format&fit=crop&q=60'),
(10, 5, 'OctaCore Edge AI Neural Compute Stick', 'Accelerated tensor processing unit (TPU) over USB 3.2 for edge machine learning inferences.', 119.99, 35, 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=500&auto=format&fit=crop&q=60'),
(11, 6, 'CloudForge 10Gbps Managed SFP+ Switch', '8-port Layer-2+ enterprise gigabit switch with two 10G SFP+ uplink ports and silent fanless cooling.', 299.99, 15, 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=500&auto=format&fit=crop&q=60'),
(12, 4, 'VaporLock Ergonomic Aluminum Laptop Stand', 'Precision CNC anodized aluminum stand with dual-hinge 360-degree rotation and heat dissipation.', 44.99, 110, 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop&q=60'),
(13, 3, 'Sentinel Smart Security Camera Hub', '2K HDR wireless security camera with on-device human detection, color night vision, and local storage.', 89.99, 40, 'https://images.unsplash.com/photo-1557324232-b8917d3c3dcb?w=500&auto=format&fit=crop&q=60'),
(14, 1, 'EchoPulse Hi-Res Studio Monitors (Pair)', 'Bi-amped nearfield reference studio monitors with custom silk dome tweeters and balanced XLR inputs.', 279.99, 18, 'https://images.unsplash.com/photo-1545454675-3531b543be5d?w=500&auto=format&fit=crop&q=60'),
(15, 1, 'MagnaCharge 3-in-1 Wireless Charging Pad', 'Fast magnetic wireless charging station for phone, smartwatch, and earbuds with LED status indicators.', 59.99, 85, 'https://images.unsplash.com/photo-1622445262464-84b1456045b6?w=500&auto=format&fit=crop&q=60'),
(16, 5, 'KubeKey FIDO2 Hardware Security Key', 'NFC + USB-C hardware authenticator for passwordless multi-factor authentication and cloud IAM access.', 54.99, 120, 'https://images.unsplash.com/photo-1563770660941-20978e870e26?w=500&auto=format&fit=crop&q=60')
ON CONFLICT (id) DO UPDATE SET 
  category_id = EXCLUDED.category_id,
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  stock_quantity = EXCLUDED.stock_quantity,
  image_url = EXCLUDED.image_url;

SELECT setval('categories_id_seq', COALESCE((SELECT MAX(id) FROM categories), 1));
SELECT setval('products_id_seq', COALESCE((SELECT MAX(id) FROM products), 1));

#!/usr/bin/env python3
import mysql.connector
import time
import threading
import random
import string
import argparse
from datetime import datetime

# Configuration
parser = argparse.ArgumentParser(description='Test MySQL Cluster with high throughput')
parser.add_argument('--host', default='localhost', help='MySQL host')
parser.add_argument('--port', type=int, default=6033, help='MySQL port (ProxySQL)')
parser.add_argument('--user', default='root', help='MySQL user')
parser.add_argument('--password', default='rootpassword', help='MySQL password')
parser.add_argument('--database', default='testdb', help='MySQL database')
parser.add_argument('--threads', type=int, default=10, help='Number of threads')
parser.add_argument('--records', type=int, default=10000, help='Records per thread')
parser.add_argument('--batch-size', type=int, default=1000, help='Batch size for inserts')
args = parser.parse_args()

# Create table if not exists
def setup_database():
    conn = mysql.connector.connect(
        host=args.host,
        port=args.port,
        user=args.user,
        password=args.password,
        database=args.database
    )
    cursor = conn.cursor()
    
    # Create a table using NDB storage engine
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS messages (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        message_id VARCHAR(36) NOT NULL,
        sender VARCHAR(20) NOT NULL,
        recipient VARCHAR(20) NOT NULL,
        message_text VARCHAR(160) NOT NULL,
        timestamp DATETIME NOT NULL,
        status TINYINT NOT NULL,
        INDEX(sender),
        INDEX(recipient),
        INDEX(timestamp)
    ) ENGINE=NDBCLUSTER
    """)
    
    conn.commit()
    cursor.close()
    conn.close()
    print("Database setup complete")

# Generate random phone number
def random_phone():
    return ''.join(random.choices(string.digits, k=10))

# Generate random message text
def random_message():
    return ''.join(random.choices(string.ascii_letters + string.digits + ' ', k=random.randint(20, 160)))

# Worker function
def worker(thread_id, records, batch_size):
    conn = mysql.connector.connect(
        host=args.host,
        port=args.port,
        user=args.user,
        password=args.password,
        database=args.database
    )
    cursor = conn.cursor()
    
    start_time = time.time()
    total_records = 0
    
    try:
        for i in range(0, records, batch_size):
            batch_records = min(batch_size, records - i)
            values = []
            
            for j in range(batch_records):
                values.append((
                    ''.join(random.choices(string.ascii_letters + string.digits, k=36)),
                    random_phone(),
                    random_phone(),
                    random_message(),
                    datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    random.randint(0, 3)
                ))
            
            cursor.executemany(
                "INSERT INTO messages (message_id, sender, recipient, message_text, timestamp, status) VALUES (%s, %s, %s, %s, %s, %s)",
                values
            )
            conn.commit()
            
            total_records += batch_records
            elapsed = time.time() - start_time
            tps = total_records / elapsed if elapsed > 0 else 0
            
            print(f"Thread {thread_id}: Inserted {total_records}/{records} records. TPS: {tps:.2f}")
    
    except Exception as e:
        print(f"Thread {thread_id} error: {e}")
    finally:
        cursor.close()
        conn.close()
    
    elapsed = time.time() - start_time
    tps = records / elapsed if elapsed > 0 else 0
    print(f"Thread {thread_id} completed. Inserted {records} records in {elapsed:.2f} seconds. TPS: {tps:.2f}")
    return tps

# Main function
def main():
    print(f"Setting up database on {args.host}:{args.port}")
    setup_database()
    
    print(f"Starting load test with {args.threads} threads, {args.records} records per thread")
    threads = []
    
    start_time = time.time()
    
    for i in range(args.threads):
        t = threading.Thread(target=worker, args=(i, args.records, args.batch_size))
        threads.append(t)
        t.start()
    
    # Wait for all threads to complete
    tps_values = []
    for t in threads:
        t.join()
    
    total_records = args.threads * args.records
    elapsed = time.time() - start_time
    total_tps = total_records / elapsed if elapsed > 0 else 0
    
    print(f"\nTest completed:")
    print(f"Total records: {total_records}")
    print(f"Total time: {elapsed:.2f} seconds")
    print(f"Overall TPS: {total_tps:.2f}")

if __name__ == "__main__":
    main()

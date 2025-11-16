#!/usr/bin/env python3
"""
DNS Traffic Analytics Collector
Collects and analyzes DNS query patterns from Pi-hole
"""

import requests
import time
import logging
import os
import json
import sqlite3
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from prometheus_client import Counter as PromCounter, Gauge, Histogram, start_http_server

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
queries_collected = PromCounter('dns_analytics_queries_collected_total', 'Total queries collected')
domains_analyzed = Gauge('dns_analytics_unique_domains', 'Number of unique domains')
clients_analyzed = Gauge('dns_analytics_unique_clients', 'Number of unique clients')
blocked_percentage = Gauge('dns_analytics_blocked_percentage', 'Percentage of blocked queries')
top_domain_queries = Gauge('dns_analytics_top_domain_queries', 'Queries for top domain', ['domain'])
collection_duration = Histogram('dns_analytics_collection_duration_seconds', 'Time to collect analytics')

# Configuration
PIHOLE_PRIMARY = os.getenv('PIHOLE_PRIMARY', '192.168.8.251')
PIHOLE_SECONDARY = os.getenv('PIHOLE_SECONDARY', '192.168.8.252')
COLLECTION_INTERVAL = int(os.getenv('COLLECTION_INTERVAL', '60'))
RETENTION_DAYS = int(os.getenv('RETENTION_DAYS', '90'))
DB_PATH = '/app/data/analytics.db'

def init_database():
    """Initialize SQLite database for analytics storage"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    # Create tables
    c.execute('''
        CREATE TABLE IF NOT EXISTS query_stats (
            timestamp INTEGER PRIMARY KEY,
            total_queries INTEGER,
            blocked_queries INTEGER,
            unique_domains INTEGER,
            unique_clients INTEGER,
            cache_hit_rate REAL
        )
    ''')
    
    c.execute('''
        CREATE TABLE IF NOT EXISTS domain_stats (
            timestamp INTEGER,
            domain TEXT,
            query_count INTEGER,
            blocked INTEGER,
            PRIMARY KEY (timestamp, domain)
        )
    ''')
    
    c.execute('''
        CREATE TABLE IF NOT EXISTS client_stats (
            timestamp INTEGER,
            client_ip TEXT,
            query_count INTEGER,
            blocked_count INTEGER,
            PRIMARY KEY (timestamp, client_ip)
        )
    ''')
    
    c.execute('''
        CREATE TABLE IF NOT EXISTS hourly_patterns (
            hour INTEGER,
            day_of_week INTEGER,
            avg_queries INTEGER,
            avg_blocked INTEGER,
            PRIMARY KEY (hour, day_of_week)
        )
    ''')
    
    conn.commit()
    conn.close()
    logger.info("Database initialized")

def collect_pihole_stats(pihole_ip):
    """Collect statistics from Pi-hole API"""
    try:
        # Get summary statistics
        response = requests.get(f'http://{pihole_ip}/admin/api.php?summary', timeout=10)
        summary = response.json()
        
        # Get top domains
        response = requests.get(f'http://{pihole_ip}/admin/api.php?topItems=50', timeout=10)
        top_items = response.json()
        
        # Get query types
        response = requests.get(f'http://{pihole_ip}/admin/api.php?getQueryTypes', timeout=10)
        query_types = response.json()
        
        return {
            'summary': summary,
            'top_items': top_items,
            'query_types': query_types
        }
    except Exception as e:
        logger.error(f"Error collecting from {pihole_ip}: {e}")
        return None

def analyze_query_patterns(stats):
    """Analyze query patterns and detect anomalies"""
    if not stats:
        return None
    
    summary = stats['summary']
    top_items = stats['top_items']
    
    analysis = {
        'total_queries': summary.get('dns_queries_today', 0),
        'blocked_queries': summary.get('ads_blocked_today', 0),
        'unique_domains': summary.get('unique_domains', 0),
        'unique_clients': summary.get('unique_clients', 0),
        'queries_cached': summary.get('queries_cached', 0),
        'queries_forwarded': summary.get('queries_forwarded', 0),
        'top_queries': top_items.get('top_queries', {}),
        'top_ads': top_items.get('top_ads', {}),
    }
    
    # Calculate percentages
    total = analysis['total_queries']
    if total > 0:
        analysis['blocked_percentage'] = (analysis['blocked_queries'] / total) * 100
        analysis['cache_hit_rate'] = (analysis['queries_cached'] / total) * 100
    else:
        analysis['blocked_percentage'] = 0
        analysis['cache_hit_rate'] = 0
    
    return analysis

def store_analytics(analysis):
    """Store analytics in database"""
    if not analysis:
        return
    
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    timestamp = int(time.time())
    
    # Store summary stats
    c.execute('''
        INSERT OR REPLACE INTO query_stats 
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (
        timestamp,
        analysis['total_queries'],
        analysis['blocked_queries'],
        analysis['unique_domains'],
        analysis['unique_clients'],
        analysis['cache_hit_rate']
    ))
    
    # Store domain stats
    for domain, count in analysis['top_queries'].items():
        blocked = 1 if domain in analysis['top_ads'] else 0
        c.execute('''
            INSERT OR REPLACE INTO domain_stats 
            VALUES (?, ?, ?, ?)
        ''', (timestamp, domain, count, blocked))
    
    conn.commit()
    conn.close()

def cleanup_old_data():
    """Remove analytics data older than retention period"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    cutoff = int((datetime.now() - timedelta(days=RETENTION_DAYS)).timestamp())
    
    c.execute('DELETE FROM query_stats WHERE timestamp < ?', (cutoff,))
    c.execute('DELETE FROM domain_stats WHERE timestamp < ?', (cutoff,))
    c.execute('DELETE FROM client_stats WHERE timestamp < ?', (cutoff,))
    
    deleted = c.rowcount
    conn.commit()
    conn.close()
    
    if deleted > 0:
        logger.info(f"Cleaned up {deleted} old records")

def update_prometheus_metrics(analysis):
    """Update Prometheus metrics"""
    if not analysis:
        return
    
    domains_analyzed.set(analysis['unique_domains'])
    clients_analyzed.set(analysis['unique_clients'])
    blocked_percentage.set(analysis['blocked_percentage'])
    
    # Update top domain metrics (top 10)
    for domain, count in list(analysis['top_queries'].items())[:10]:
        top_domain_queries.labels(domain=domain).set(count)

def collection_loop():
    """Main collection loop"""
    logger.info("DNS Traffic Analytics started")
    logger.info(f"Collecting from: {PIHOLE_PRIMARY}, {PIHOLE_SECONDARY}")
    logger.info(f"Collection interval: {COLLECTION_INTERVAL}s")
    logger.info(f"Data retention: {RETENTION_DAYS} days")
    
    init_database()
    
    while True:
        try:
            start_time = time.time()
            logger.info("Collecting DNS analytics...")
            
            # Collect from primary Pi-hole
            stats = collect_pihole_stats(PIHOLE_PRIMARY)
            
            if stats:
                # Analyze patterns
                analysis = analyze_query_patterns(stats)
                
                # Store in database
                store_analytics(analysis)
                
                # Update Prometheus metrics
                update_prometheus_metrics(analysis)
                
                # Update collection metrics
                queries_collected.inc(analysis['total_queries'])
                
                logger.info(f"Collected: {analysis['total_queries']} total queries, "
                           f"{analysis['blocked_queries']} blocked ({analysis['blocked_percentage']:.1f}%)")
            
            # Cleanup old data (once per day)
            if int(time.time()) % 86400 < COLLECTION_INTERVAL:
                cleanup_old_data()
            
            duration = time.time() - start_time
            collection_duration.observe(duration)
            
            time.sleep(COLLECTION_INTERVAL)
            
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            break
        except Exception as e:
            logger.error(f"Error in collection loop: {e}")
            time.sleep(COLLECTION_INTERVAL)

if __name__ == '__main__':
    # Ensure data directory exists
    os.makedirs('/app/data', exist_ok=True)
    
    # Start Prometheus metrics server
    start_http_server(8082)
    logger.info("Prometheus metrics server started on port 8082")
    
    # Start collection loop
    collection_loop()

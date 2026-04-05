const https = require('https');

const supabaseUrl = 'vmjojqhtvhwuqopdqgpa.supabase.co';
const apiKey = 'sb_publishable_5E-fjPw5BjyUX8EOOy26rQ_SU7AQ02M';

const tables = ['profiles', 'products', 'orders'];

async function fetchTableSchema(tableName) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: supabaseUrl,
      path: `/rest/v1/${tableName}?limit=1&select=*`,
      method: 'GET',
      headers: {
        'apikey': apiKey,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (Array.isArray(parsed) && parsed.length > 0) {
            const columns = Object.keys(parsed[0]);
            resolve({ table: tableName, columns, status: res.statusCode });
          } else {
            resolve({ table: tableName, columns: [], status: res.statusCode, message: 'Empty table' });
          }
        } catch (e) {
          resolve({ table: tableName, columns: [], status: res.statusCode, error: data });
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

(async () => {
  console.log('🔍 Fetching Supabase Table Schemas...\n');
  for (const table of tables) {
    try {
      const result = await fetchTableSchema(table);
      console.log(`📋 ${result.table} (Status: ${result.status})`);
      if (result.columns.length > 0) {
        console.log('   Columns:');
        result.columns.forEach(col => console.log(`     • ${col}`));
      } else {
        console.log('   ⚠️  ' + (result.message || result.error || 'No columns found'));
      }
      console.log('');
    } catch (err) {
      console.log(`❌ Error fetching ${table}: ${err.message}\n`);
    }
  }
})();

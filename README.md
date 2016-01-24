# Lovebus

Crawl for dope images on Tumblr. A la archillect.

1. Copy the sample env to `.env`
2. Register a tumblr API key https://www.tumblr.com/oauth/apps
3. Add your API key to the .env
4. Start the crawler `foreman run rake spider:tumblr_import`
5. Add keywords to the blacklist at `lib/initializers/obscenity.rb`
6. See the glory of your work at `localhost:3000/images`

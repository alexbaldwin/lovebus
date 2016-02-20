# Lovebus

Crawl for dope images on Tumblr. A la archillect.

1. Copy the sample env to `.env`
1. Register a tumblr API key https://www.tumblr.com/oauth/apps
1. Add your API key to the .env
1. Start the crawler `foreman run rake spider:tumblr_import`
1. Add keywords to the blacklist at `lib/initializers/obscenity.rb`
1. See the glory of your work at `localhost:3000/images`

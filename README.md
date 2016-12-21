#  ZnetLocalToStatsd

Simple poller for sensor data using the Tellstick net local api ( http://api.telldus.net/localapi/api.html ). 
Fetches sensor values and pushes them to statsd.

## Why
Local API gives you current metric info and is not bound by cloud services by Telldus. 

The Cloud API only updates a value every 10 minutes (or 5 if you've paid for PRO).

## Usage

Run `bin/ruby`. We will scrape all sensors on each sweep and push each metric to statsd. Format is: ` # tellstick.sensorX.temp(N)` eg. `tellstick.garage.temp` 
Each metric name / value will also we logged to stdout for easy monitoring/debugging

### Creating access token

When running this for the first time you need to create an access token to be used. You can read about the process in the API docs, but tl;dr is that you need to accept the usage via web browser.

Just run this normally via `bin/run` and if theres no working token supplied it will prompt you to go to an url to create one. Token will be persisted in `~/.tellstick_token` / `TOKEN_LOCATION`

## Environment variables / configs

After you've created an access token it can be supplied via ENV variable called `TOKEN` or in a file (default `~/.tellstick_token` but can be supplied via `TOKEN_LOCATION` ENV)
Other variables are:

- `STICK_ADDRESS` => IP / hostname of your tellstick_token. Default: `tellstick`
- `STATSD_ADDR` / `STATSD_PORT` => Location of statsd. Default `localhost:8125`
- `SLEEP_DURATION` => Polling interval

## Docker

Docker builds available at https://hub.docker.com/r/n1koo/znet_local_to_statsd/

For running kubernetes you can use this example configuration:

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: znet-local-to-statsd
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: znet-local-to-statsd
    spec:
      containers:
      - name: znet-local-to-statsd
        image: n1koo/znet_local_to_statsd
        imagePullPolicy: Always
        env:
          - name: TOKEN
            value: "xxx"
          - name: STATSD_ADDR
            value: statsd.default
          - name: STATSD_PORT
            value: "8125"
          - name: STICK_ADDRESS
            value: "tellstick"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/znet_local_to_statsd.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


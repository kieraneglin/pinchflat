# Pinchflat (Alpha)

This is alpha software and anything can break at any time. I make not guarantees about the stability of this software, forward-compatibility of updates, or integrity (both related to and independent of Pinchflat). Essentially, use at your own risk and expect there will be rough edges.

## EFF Donation Receipts

A portion of all donations to Pinchflat will be donated to the Electronic Frontier Foundation. [See here](https://github.com/kieraneglin/pinchflat/wiki/EFF-Donation-Receipts) for a list of donation receipts.

## What is Pinchflat?

TODO: expand on this.

Pinchflat is a lightweight self-contained app for downloading YouTube content. For now, it is not intended as a way to consume content, but instead as a way to download content to disk using specified rules and schedules.

I have plans for more to come, but for now this is the focus. Think of Pinchflat as nothing more than an automated way to get content from YouTube to your disk.

## Installation

Pinchflat is designed to be self-hosted. I'm building it for my own needs which means it's designed to work well with Unraid, but it should work on any computer/server that can run Docker images.

I'll update with Unraid instructions once I get something in the Community Apps store. Until then, here's how you build it with Docker:

```bash
docker build . --file selfhosted.Dockerfile -t pinchflat:dev

docker run \
  -p 8945:8945 \
  -v /Users/work/Desktop/test_volumes/config:/config \
  -v /Users/work/Desktop/test_volumes/downloads:/downloads \
  pinchflat:dev
```

## Authentication

Currently HTTP basic auth is optionally supported. To use it, set the `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD` environment variables when starting the container. If you don't set both of these, no authentication will be required.

## License

See `LICENSE` file

```

```

FROM mongo:3.6.4

RUN mkdir /data/users
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

# Run mongodb
CMD ["mongod"]

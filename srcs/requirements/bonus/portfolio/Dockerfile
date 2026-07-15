FROM debian:13

# Install prerequisites (.net SDK requires ca-certificates and apt-transport-https because 
#                           .net SDK is not available in the default Debian repositories)
RUN apt-get update && \
    apt-get install -y wget apt-transport-https ca-certificates && \
    wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-sdk-10.0

WORKDIR /app

COPY ./App .

# Restore dependencies
RUN dotnet restore

# Build and publish
RUN dotnet publish -c Release -o /app/publish

# Run from the published output
WORKDIR /app/publish

# Kestrel listens on port 5000
ENV ASPNETCORE_URLS=http://+:5000

EXPOSE 5000

CMD ["dotnet", "cv.dll"]
# PROTEQT Spark History Analytics

This standalone Scala + Apache Spark demo reads the Flutter history CSV export format:

```text
id,eventType,timestamp,description
```

It does not connect to Flutter or the SQLite database. Export or copy history records to `sample_history.csv` before running it.

## Requirements on Windows

Install Apache Spark 4.2.0 for Hadoop 3, Java 17, and Scala 2.13.18. Add their `bin` directories to `PATH`:

- Java 17
- Apache Spark 4.2.0 built for Hadoop 3
- Scala 2.13.18

Verify the tools in PowerShell:

```powershell
$env:SPARK_HOME = "D:\Spark\spark-4.2.0-bin-hadoop3"
java --version
& "$env:SPARK_HOME\bin\spark-shell.cmd" --version
& "$env:SPARK_HOME\bin\spark-submit.cmd" --version
scalac -version
```

## Run with spark-shell

For the Spark installation at `D:\Spark\spark-4.2.0-bin-hadoop3`, run these commands from `D:\proteqt`:

```powershell
$env:SPARK_HOME = "D:\Spark\spark-4.2.0-bin-hadoop3"
Set-Location D:\proteqt
& "$env:SPARK_HOME\bin\spark-shell.cmd" --master "local[*]" -i .\spark_history\HistoryAnalytics.scala
```

At the Spark shell prompt, run:

```scala
HistoryAnalytics.main(Array("spark_history/sample_history.csv"))
```

The program prints a PROTEQT SAFETY ANALYTICS report and then stops its Spark session.

## Run with spark-submit

Compile `HistoryAnalytics.scala` into a JAR with the standalone Scala 2.13.18 compiler. The Scala compiler and Spark 4.2.0 must use the same Scala 2.13 binary version. The following commands are PowerShell-compatible and do not use Scala CLI:

```powershell
New-Item -ItemType Directory -Force .\spark_history\classes | Out-Null
scalac -classpath "$env:SPARK_HOME\jars\*" -d .\spark_history\classes .\spark_history\HistoryAnalytics.scala
jar -cf .\spark_history\proteqt-history-analytics.jar -C .\spark_history\classes .
& "$env:SPARK_HOME\bin\spark-submit.cmd" --class HistoryAnalytics --master "local[*]" .\spark_history\proteqt-history-analytics.jar .\spark_history\sample_history.csv
```

## Expected report

The report includes total events, counts for each supported event type, the most active calendar day, and the most active period: Night, Morning, Afternoon, or Evening. Empty or timestamp-invalid input is handled without failing; its active day and period are reported as `N/A`.
